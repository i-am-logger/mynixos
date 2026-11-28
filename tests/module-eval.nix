{ lib
, nixpkgs
, system
, self
, inputs
}:

let
  testLib = import ./lib.nix { inherit lib nixpkgs system self inputs; };
  inherit (testLib) pkgs specialArgs baseModules baseConfig;

  herdrSession = import ../my/users/apps/multiplexers/herdr/session.nix { inherit lib pkgs; };
  plain = builtins.unsafeDiscardStringContext;

  # Helper: evaluate a NixOS system with the mynixos module and given config.
  #
  # These checks used to force `networking.hostName` alone, which is set by the
  # test config itself -- so they passed without evaluating any mynixos module's
  # output. What they actually prove depends entirely on how hard they pull, so
  # they now force the four places module config lands: system packages, the
  # per-user home-manager package sets, the systemd unit names and the created
  # accounts.
  #
  # `system.build.toplevel` is deliberately NOT forced. vogix uses
  # import-from-derivation, so building the toplevel needs an x86_64-linux
  # builder at EVALUATION time -- which would make these checks unrunnable
  # anywhere else, for no extra coverage of mynixos itself.
  # Like evalTest, but also asserts a predicate over the resulting config, so the
  # check fails when the modules produce the wrong VALUES rather than merely
  # evaluating.
  evalAssert = name: testConfig: predicate:
    let
      eval = lib.nixosSystem {
        inherit specialArgs;
        modules = baseModules ++ [ baseConfig testConfig ];
      };
      ok = predicate eval.config;
    in
    if !ok then builtins.throw "FAIL: module-eval-${name} -- config assertion did not hold"
    else
      pkgs.runCommand "module-eval-${name}" { } ''
        echo "PASS: ${name}"
        touch $out
      '';

  # Like evalAssert, but the predicate returns named clauses, and a failure
  # names every clause that did not hold.
  evalClauses = name: testConfig: clauses:
    let
      eval = lib.nixosSystem {
        inherit specialArgs;
        modules = baseModules ++ [ baseConfig testConfig ];
      };
      failed = builtins.attrNames (lib.filterAttrs (_: ok: !ok) (clauses eval.config));
    in
    if failed != [ ] then builtins.throw "FAIL: module-eval-${name} -- did not hold: ${lib.concatStringsSep ", " failed}"
    else
      pkgs.runCommand "module-eval-${name}" { } ''
        echo "PASS: ${name}"
        touch $out
      '';

  # Like evalAssert, but for a whole SYSTEM mkSystem already built, rather
  # than a module list this file assembles. Such a system brings its own module set
  # and its own architecture, so baseModules/baseConfig do
  # not apply: handing it those would test a hand-built lookalike instead of
  # what a consumer actually writes.
  # Named for what these check: a machine configured to be a seed or a builder,
  # seen as the container image a host would run. They used to be
  # `self.lib.roles.radicle.*` -- constructors mynixos shipped -- and are now
  # ordinary systems with `infra.radicle.{seed,builder}.enable`, which is the
  # whole point: a consumer can write this, and could not write a role.
  systemAssert = name: role: predicate:
    let
      ok = predicate role.config
        # Forced so the check reaches the real closure and every assertion in
        # it, not just the option values the predicate happens to name.
        && builtins.deepSeq role.config.system.build.image.drvPath true;
    in
    if !ok then builtins.throw "FAIL: module-eval-${name} -- config assertion did not hold"
    else
      pkgs.runCommand "module-eval-${name}" { } ''
        echo "PASS: ${name}"
        touch $out
      '';

  evalTest = name: testConfig:
    let
      eval = lib.nixosSystem {
        inherit specialArgs;
        modules = baseModules ++ [ baseConfig testConfig ];
      };
      inherit (eval) config;

      # `attrNames` alone would force only the KEY SET -- a unit whose script or
      # serviceConfig is wrong, or a program whose settings are silently dropped,
      # would still pass. These force the values.
      forced = builtins.deepSeq
        {
          packages = map (p: p.name or "?") config.environment.systemPackages;
          # Names only. Forcing unit VALUES reaches the vogix home-manager
          # activation service, whose data comes from an import-from-derivation
          # that needs an x86_64-linux builder at evaluation time -- the same
          # reason system.build.toplevel is not forced. Deep-forcing the whole
          # unit set also exhausts the evaluator's call depth.
          units = builtins.attrNames config.systemd.services;
          accounts = lib.mapAttrs
            (_: u: { isNormalUser = u.isNormalUser or false; inherit (u) extraGroups; })
            config.users.users;
          home = lib.mapAttrs
            (_: u: {
              packages = map (p: p.name or "?") u.home.packages;
              files = builtins.attrNames u.home.file;
              sessionVariables = u.home.sessionVariables;
              # NOT forced: every `programs.<x>.enable`. home-manager declares
              # hundreds, and walking them all overflows the evaluator. The
              # multiplexer checks below force specific programs.*.settings
              # instead, which is where a mis-gated module actually shows up.
            })
            config.home-manager.users;
        }
        "ok";
    in
    pkgs.runCommand "module-eval-${name}" { } ''
      echo "Evaluated ${name}: ${forced} (${toString (builtins.length config.environment.systemPackages)} system packages)"
      touch $out
    '';

  # --- herdr plugins ----------------------------------------------------------
  #
  # pkgs is not in specialArgs (tests/lib.nix), so a nixpkgs overlay in the test
  # config reaches the modules. Each case names its herdr version that way, in
  # both directions, so no case depends on which herdr mynixos's own nixpkgs
  # pin ships (0.9.0 today, below the plugins' 0.9.1 floor).
  herdrAt = version: {
    nixpkgs.overlays = [
      (_: prev: { herdr = prev.herdr.overrideAttrs (_: { inherit version; __intentionallyOverridingVersion = true; }); })
    ];
  };

  evalHerdr = version: testConfig: (lib.nixosSystem {
    inherit specialArgs;
    modules = baseModules ++ [ baseConfig (herdrAt version) testConfig ];
  }).config;

  # The FAILING assertions whose message contains `needle`. Only failing ones:
  # NixOS's own assertions build their message from values that exist only
  # when the assertion fails (filesystems.nix reads `fileSystems'.cycle`), so
  # reading the message of one that holds is an evaluation error.
  failing = needle: config:
    builtins.filter (a: !a.assertion && lib.hasInfix needle a.message) config.assertions;

  # Accepts: no assertion mentioning `needle` fails, and `predicate` holds.
  # That the assertion exists at all is what each case's refusing twin proves.
  herdrAccepts = name: version: needle: testConfig: predicate:
    let
      config = evalHerdr version testConfig;
    in
    if failing needle config != [ ] then builtins.throw "FAIL: module-eval-${name} -- '${needle}' fired"
    else if !(predicate config) then builtins.throw "FAIL: module-eval-${name} -- config assertion did not hold"
    else pkgs.runCommand "module-eval-${name}" { } "echo PASS: ${name}; touch $out";

  # Refuses: an assertion mentioning `needle` fails. Any other failing
  # assertion does not count, so an unrelated failure cannot pass this.
  herdrRefuses = name: version: needle: testConfig:
    if failing needle (evalHerdr version testConfig) == [ ]
    then builtins.throw "FAIL: module-eval-${name} -- '${needle}' did not fire"
    else pkgs.runCommand "module-eval-${name}" { } "echo PASS: ${name}; touch $out";

  herdrUser = herdr: extra: {
    networking.hostName = "test-herdr-plugins";
    my.users.muxuser = {
      fullName = "Mux User";
      description = "mux";
      email = "mux@example.com";
      terminal = { enable = true; multiplexer = "herdr"; inherit herdr; };
    } // extra;
  };

  hmOf = config: config.home-manager.users.muxuser;

  # claude-code's claudeMergedSettings activation step, usageRecord on or
  # off, and the settings set that step merges (its --argjson argument).
  usageRecordStep = enable:
    (hmOf (lib.nixosSystem {
      inherit specialArgs;
      modules = baseModules ++ [
        baseConfig
        (herdrUser { } { apps.ai.tools.claude-code = { enable = true; usageRecord = { inherit enable; }; }; })
      ];
    }).config).home.activation.claudeMergedSettings.data;
  mergedOfStep = step: builtins.fromJSON (builtins.unsafeDiscardStringContext
    (lib.head (lib.splitString "'" (lib.elemAt (lib.splitString "--argjson m '" step) 1))));

  # A herdr user with claude-code and `accounts`, on the /persist fixture.
  accountsOnPersist = accounts: lib.recursiveUpdate
    (herdrUser { } { apps.ai.tools.claude-code = { enable = true; inherit accounts; }; })
    {
      fileSystems."/persist" = {
        device = "/dev/disk/by-label/persist";
        fsType = "ext4";
        neededForBoot = true;
      };
      my.storage.impermanence.enable = true;
    };
  hasPname = name: hm: builtins.any (p: (p.pname or "") == name) hm.home.packages;
  # What config.toml is generated from. pkgs.formats.toml keeps the value on
  # the derivation (`value`, structured attrs), so it reads without a build.
  herdrSettings = hm: hm.xdg.configFile."herdr/config.toml".source.value;
  activation = hm: hm.home.activation.herdrPlugins.data;
  keysOf = hm: map (k: k.command) ((herdrSettings hm).keys.command or [ ]);
  headMark = builtins.fromJSON ''"​"'';

  # --- my.hardware.display ----------------------------------------------------
  #
  # A graphical Hyprland user with theming off, so what is asserted is mynixos's
  # own rendering of the display domain into the Lua settings.
  displayHost = display: {
    networking.hostName = "test-display";
    my = {
      theming = {
        enable = false;
        vogix.enable = false;
      };
      hardware.display = display;
      users.hypruser = {
        fullName = "Hypr User";
        description = "hypr";
        email = "hypr@example.com";
        graphical.enable = true;
        apps.graphical.windowManagers.hyprland.enable = true;
      };
    };
  };

  hyprSettings = config: config.home-manager.users.hypruser.wayland.windowManager.hyprland.settings;
  monitorRules = config: (hyprSettings config).monitor;
  ruleFor = output: config: lib.findFirst (r: r.output == output) null (monitorRules config);

  # The built-in defaults as a wildcard: highest resolution then refresh, 10-bit
  # HDR with SDR content at 203 nits, VRR for fullscreen.
  displayWildcard = {
    output = "";
    mode = "highres";
    position = "auto";
    scale = "1";
    bitdepth = 10;
    cm = "hdr";
    sdr_max_luminance = 203;
    vrr = 3;
  };

  aw = "desc:Dell Inc. AW3225QF";

  # No display assertion fails: an accepted configuration must also be a valid one.
  displayClean = config: failing "my.hardware.display" config == [ ];

  # Refuses: an assertion mentioning `needle` fails. Evaluated without a user,
  # because the display assertions belong to the system, not to Hyprland.
  displayRefuses = name: needle: testConfig:
    let
      inherit ((lib.nixosSystem {
        inherit specialArgs;
        modules = baseModules ++ [ baseConfig { networking.hostName = "test-display-refuse"; } testConfig ];
      })) config;
    in
    if failing needle config == [ ]
    then builtins.throw "FAIL: module-eval-${name} -- '${needle}' did not fire"
    else pkgs.runCommand "module-eval-${name}" { } "echo PASS: ${name}; touch $out";

  # A kernel package set whose version reads as `version`, for the FRL gate.
  # Only `kernel.version` is read, so nothing is built.
  kernelAt = version: { pkgs, ... }: {
    boot.kernelPackages = pkgs.linuxPackagesFor (pkgs.linux_latest.override {
      argsOverride = { inherit version; modDirVersion = version; };
    });
  };

in
{
  # Test 1: Module imports without errors (empty config, no my.* options set)
  minimal = evalTest "minimal" {
    networking.hostName = "test-minimal";
  };

  # Test 2: Core system module evaluates with basic options
  system-core = evalTest "system-core" {
    networking.hostName = "test-system";
    my.system.enable = true;
    my.system.hostname = "test-system";
  };

  # Test 3: Performance module evaluates
  performance = evalTest "performance" {
    networking.hostName = "test-performance";
    my.performance.enable = true;
  };

  # Test 4: Hardware CPU and GPU options can be set
  hardware = evalTest "hardware" {
    networking.hostName = "test-hardware";
    my.hardware.cpu = "amd";
    my.hardware.gpu = "amd";
  };

  # Test 5: A user with features enabled evaluates
  # There is no `my.users.<n>.features`; the per-user feature flags are
  # top-level submodules with their own `enable`. This config named the option
  # that never existed and still passed, because the check only forced
  # `networking.hostName` and so never merged the definition.
  # Multiplexer selection. The zellij module used to gate on an app option that
  # nothing set, so its whole settings block was discarded while
  # `programs.zellij.enable` was true from elsewhere -- the enable flag alone
  # therefore proves nothing. These force the SETTINGS, and assert the two
  # multiplexers are mutually exclusive.
  multiplexer-zellij = evalAssert "multiplexer-zellij"
    {
      networking.hostName = "test-mux-zellij";
      my.users.muxuser = {
        fullName = "Mux User";
        description = "mux";
        email = "mux@example.com";
        terminal = { enable = true; multiplexer = "zellij"; };
      };
    }
    (config:
      let hm = config.home-manager.users.muxuser; in
      hm.programs.zellij.enable
      && hm.programs.zellij.settings.default_layout == "compact"
      && hm.programs.zellij.settings.copy_on_select
      && !hm.programs.tmux.enable);

  multiplexer-tmux = evalAssert "multiplexer-tmux"
    {
      networking.hostName = "test-mux-tmux";
      my.users.muxuser = {
        fullName = "Mux User";
        description = "mux";
        email = "mux@example.com";
        terminal = { enable = true; multiplexer = "tmux"; };
      };
    }
    (config:
      let hm = config.home-manager.users.muxuser; in
      hm.programs.tmux.enable && !hm.programs.zellij.enable);

  # herdr has no home-manager module, so its own module is what puts the package
  # on PATH and writes the config -- assert both, not just mutual exclusion.
  multiplexer-herdr = evalAssert "multiplexer-herdr"
    {
      networking.hostName = "test-mux-herdr";
      my.users.muxuser = {
        fullName = "Mux User";
        description = "mux";
        email = "mux@example.com";
        terminal = { enable = true; multiplexer = "herdr"; };
      };
    }
    (config:
      let hm = config.home-manager.users.muxuser; in
      builtins.any (p: (p.pname or "") == "herdr") hm.home.packages
      && hm.xdg.configFile ? "herdr/config.toml"
      && lib.all (init: lib.hasInfix (plain herdrSession.shellInit) (plain init))
        [ hm.programs.bash.initExtra hm.programs.zsh.initContent ]
      && !hm.programs.zellij.enable
      && !hm.programs.tmux.enable);

  # What bash and zsh run at start, run: in a herdr pane it exports the workspace
  # id and label, or the id alone where herdr answers nothing; outside one, nothing.
  herdr-releasable-session =
    let
      init = pkgs.writeText "herdr-shell-init" herdrSession.shellInit;
      labelled = pkgs.writeShellScript "fake-herdr" ''
        [ "$1 $2 $3" = "workspace get w7" ] || exit 2
        echo '{"result":{"workspace":{"workspace_id":"w7","label":"two words"}}}'
      '';
      silent = pkgs.writeShellScript "fake-herdr-down" "exit 1";
      run = shell: env: "env -i ${env} ${shell} -c '. ${init}; printf %s \"\${RELEASABLE_SESSION-unset}\"'";
    in
    pkgs.runCommand "module-eval-herdr-releasable-session" { } ''
      for sh in ${pkgs.bash}/bin/bash ${pkgs.zsh}/bin/zsh; do
        got=$(${run "$sh" "HERDR_WORKSPACE_ID=w7 HERDR_BIN_PATH=${labelled}"})
        [ "$got" = "w7 two words" ] || { echo "FAIL: $sh in a pane: $got"; exit 1; }
        got=$(${run "$sh" "HERDR_WORKSPACE_ID=w7 HERDR_BIN_PATH=${silent}"})
        [ "$got" = "w7" ] || { echo "FAIL: $sh, herdr answering nothing: $got"; exit 1; }
        got=$(${run "$sh" ""})
        [ "$got" = "unset" ] || { echo "FAIL: $sh outside herdr: $got"; exit 1; }
      done
      echo "PASS: herdr-releasable-session" > $out
    '';

  # The point of the whole arrangement: terminal.multiplexer is declared in four
  # files (my/users/terminal/options.nix plus one per multiplexer), and only
  # herdr's carries a default. State no multiplexer at all and herdr must be
  # what comes out -- if the enum declarations ever stop merging, this is the
  # case that catches it.
  multiplexer-default = evalAssert "multiplexer-default"
    {
      networking.hostName = "test-mux-default";
      my.users.muxuser = {
        fullName = "Mux User";
        description = "mux";
        email = "mux@example.com";
        terminal.enable = true;
      };
    }
    (config:
      let user = config.my.users.muxuser; in
      user.terminal.multiplexer == "herdr");

  # Off by default: no plugin package, no PATH link, nothing linked, and
  # status_indicators at the option's default.
  herdr-plugins-default-off = herdrAccepts "herdr-plugins-default-off" "0.9.0" "need herdr >= 0.9.1"
    (herdrUser { } { })
    (config:
      let hm = hmOf config; in
      !(hasPname "herdr-projects" hm)
      && !(hm.home.file ? ".local/bin/herdr-projects")
      && !(lib.hasInfix "plugin link" (activation hm))
      # The entry still exists: it unlinks what an earlier generation linked.
      && lib.hasInfix "plugin unlink" (activation hm)
      && (herdrSettings hm).ui.status_indicators == "dots"
      && !((herdrSettings hm).ui ? tab_bar_right)
      && !((herdrSettings hm) ? keys));

  herdr-status-indicators-symbols = evalAssert "herdr-status-indicators-symbols"
    (herdrUser { statusIndicators = "symbols"; } { })
    (config: (herdrSettings (hmOf config)).ui.status_indicators == "symbols");

  # herdr-projects: the owner's rows, tab-bar entry and key, the link and the
  # PATH link, at a herdr new enough.
  herdr-plugins-projects = herdrAccepts "herdr-plugins-projects" "0.9.5" "need herdr >= 0.9.1"
    (herdrUser { plugins.projects.enable = true; } { })
    (config:
      let
        hm = hmOf config;
        inherit (herdrSettings hm) ui;
        card = builtins.elemAt (builtins.head ui.sidebar.agents.rows) 1;
      in
      hasPname "herdr-projects" hm
      && hm.home.file.".local/bin/herdr-projects".force
      && lib.hasInfix "plugin link" (activation hm)
      && lib.hasInfix "share/herdr-plugins/herdr-projects" (activation hm)
      && keysOf hm == [ "herdr-projects.open-popup" ]
      && (builtins.head (herdrSettings hm).keys.command).key == "prefix+a"
      && lib.hasInfix "needs-you --line" (builtins.head ui.tab_bar_right).command
      && (builtins.head card.rules).contains == headMark
      && builtins.length ui.sidebar.spaces.rows == 1
      && !(ui.sidebar.agents ? rows_by_agent));

  herdr-plugins-projects-old-herdr = herdrRefuses "herdr-plugins-projects-old-herdr" "0.9.0" "need herdr >= 0.9.1"
    (herdrUser { plugins.projects.enable = true; } { });

  # A plugin's own floor, above the module's: reviewr needs 0.9.3.
  herdr-plugins-reviewr = herdrAccepts "herdr-plugins-reviewr" "0.9.5" "reviewr needs herdr >= 0.9.3"
    (herdrUser { plugins.reviewr.enable = true; } { })
    (config:
      let hm = hmOf config; in
      hasPname "herdr-reviewr" hm
      && keysOf hm == [ "persiyanov.reviewr.toggle" ]
      && lib.hasInfix "share/herdr-plugins/herdr-reviewr" (activation hm));

  herdr-plugins-reviewr-old-herdr = herdrRefuses "herdr-plugins-reviewr-old-herdr" "0.9.2" "reviewr needs herdr >= 0.9.3"
    (herdrUser { plugins.reviewr.enable = true; } { });

  # clauth is gone (app, package, daemon, herdr plugin). Its herdr
  # registration from earlier generations is unlinked on activation, so the
  # registry never keeps an entry naming a garbage-collected store path.
  no-clauth = evalAssert "no-clauth"
    (herdrUser { plugins.projects.enable = true; } { })
    (config:
      let
        u = config.my.users.muxuser;
        hm = hmOf config;
      in
      !(u.apps.ai.tools ? clauth)
      && !(u.terminal.herdr.plugins ? clauth)
      && !(hasPname "clauth" hm)
      && lib.hasInfix "plugin unlink clauth" (activation hm)
      && !((herdrSettings hm).ui.sidebar.agents ? rows_by_agent));

  # Two plugins on one key, and a plugin on a herdr built-in.
  herdr-plugins-key-collision = herdrRefuses "herdr-plugins-key-collision" "0.9.5" "two plugins bind one key"
    (herdrUser
      { plugins = { projects.enable = true; usage = { enable = true; popupKey = "prefix+a"; }; }; }
      { });

  herdr-plugins-key-builtin = herdrRefuses "herdr-plugins-key-builtin" "0.9.5" "is a herdr built-in binding"
    (herdrUser { plugins.projects = { enable = true; popupKey = "prefix+s"; }; } { });

  herdr-plugins-key-builtin-indexed = herdrRefuses "herdr-plugins-key-builtin-indexed" "0.9.5" "is a herdr built-in binding"
    (herdrUser { plugins.usage = { enable = true; popupKey = "prefix+3"; }; } { });

  # Every plugin on at its default keys: no key assertion fires.
  herdr-plugins-all-keys-distinct = herdrAccepts "herdr-plugins-all-keys-distinct" "0.9.5" "bind"
    (herdrUser
      { plugins = { projects.enable = true; radar.enable = true; usage.enable = true; reviewr.enable = true; }; }
      { })
    (config: builtins.length (keysOf (hmOf config)) == 3);

  # radar: its tab-bar entry beside herdr-projects', its own config, and no
  # sidebar rows of its own.
  herdr-plugins-radar = herdrAccepts "herdr-plugins-radar" "0.9.5" "radar needs herdr"
    (herdrUser { plugins = { projects.enable = true; radar.enable = true; }; } { })
    (config:
      let
        hm = hmOf config;
        inherit (herdrSettings hm) ui;
        radarCfg = hm.xdg.configFile."herdr/plugins/config/hhdebb.herdr-radar/config.toml".source.value;
      in
      builtins.length ui.tab_bar_right == 2
      && lib.hasInfix "/herdr/plugins/hhdebb.herdr-radar/tabbar\${HERDR_SESSION:+-$HERDR_SESSION}.txt" (lib.last ui.tab_bar_right).command
      && ui.tab_bar_right_separator == " · "
      && radarCfg == { follow_appearance = false; variant = "text"; }
      && builtins.length ui.sidebar.agents.rows == 2);

  herdr-plugins-radar-off = evalAssert "herdr-plugins-radar-off"
    (herdrUser { plugins.projects.enable = true; } { })
    (config:
      let hm = hmOf config; in
      !(hm.xdg.configFile ? "herdr/plugins/config/hhdebb.herdr-radar/config.toml")
      && !((herdrSettings hm).ui ? tab_bar_right_separator));

  # usage: the gauge rows after herdr-projects' Space card. No account roster:
  # the plugin reads the global Claude Code login.
  herdr-plugins-usage = herdrAccepts "herdr-plugins-usage" "0.9.5" "usage needs herdr"
    (herdrUser { plugins = { projects.enable = true; usage.enable = true; }; } {
      apps.ai.tools.claude-code.enable = true;
    })
    (config:
      let
        hm = hmOf config;
        spaces = (herdrSettings hm).ui.sidebar.spaces.rows;
      in
      builtins.length spaces == 5
      && (builtins.head (builtins.elemAt spaces 1)).token == "$cu"
      && !(hm.xdg.configFile ? "herdr/plugins/config/houser.claude-usage/accounts.json"));

  # usage alone: the gauges without herdr-projects' row.
  herdr-plugins-usage-alone = evalAssert "herdr-plugins-usage-alone"
    (herdrUser { plugins.usage.enable = true; } { })
    (config:
      let hm = hmOf config; in
      !(hm.xdg.configFile ? "herdr/plugins/config/houser.claude-usage/accounts.json")
      && builtins.length (herdrSettings hm).ui.sidebar.spaces.rows == 4);

  # Claude Code is upstream's package: no account wrapper.
  claude-code-plain = evalAssert "claude-code-plain"
    (herdrUser { } { apps.ai.tools.claude-code.enable = true; })
    (config:
      let package = (hmOf config).programs.claude-code.package; in
      (package.pname or "") == "claude-code" && !(package ? paths));

  # runs.slice: releasable reads the user manager's runs.slice MemoryMax and
  # refuses every run while it is infinity. A budget alone (no
  # performance.enable) declares it, with no swap, no MemoryHigh and no CPU
  # property; without a budget there is none.
  performance-runs-budget = evalAssert "performance-runs-budget"
    { networking.hostName = "test-runs"; my.performance.runs.budget = "128G"; }
    (config:
      let
        lines = lib.filter (l: l != "")
          (lib.splitString "\n" config.systemd.user.units."runs.slice".text);
      in
      lib.elem "MemoryMax=128G" lines
      && lib.elem "MemorySwapMax=0" lines
      && !(lib.any (lib.hasPrefix "MemoryHigh") lines)
      && !(lib.any (l: lib.hasPrefix "CPU" l || lib.hasPrefix "AllowedCPUs" l) lines));

  # runs.slice is exempt from systemd-oomd, so MemoryMax is its one bound:
  # mynixos's oomd drop-in (slice.d/overrides.conf, kill at 80% pressure)
  # covers every user slice, and a later-sorting runs.slice.d drop-in sets it
  # back to auto. Read from the generated unit tree systemd loads.
  performance-runs-oomd-exempt = evalAssert "performance-runs-oomd-exempt"
    { networking.hostName = "test-runs-oomd"; my.performance.runs.budget = "128G"; }
    (config:
      let
        units = config.environment.etc."systemd/user".source;
        dropins = builtins.attrNames (builtins.readDir "${units}/runs.slice.d");
        last = lib.last (lib.sort lib.lessThan (dropins ++ [ "overrides.conf" ]));
      in
      last == "zz-oomd-exempt.conf"
      && lib.hasInfix "ManagedOOMMemoryPressure=auto" (builtins.readFile "${units}/runs.slice.d/${last}"));

  performance-runs-no-budget = evalAssert "performance-runs-no-budget"
    { networking.hostName = "test-runs-none"; my.performance.enable = true; }
    (config: !(config.systemd.user.units ? "runs.slice"));

  # `nixpkgs` in the registry and on NIX_PATH is the nixpkgs the system was
  # built from, and NIX_PATH holds nothing else: no channels entry.
  nix-registry-pinned = evalAssert "nix-registry-pinned" { }
    (config:
      toString config.nix.registry.nixpkgs.to.path == toString inputs.nixpkgs.outPath
      && config.nix.nixPath == [ "nixpkgs=flake:nixpkgs" ]
      && !config.nix.channel.enable);

  # fleetWake: the path unit watches new/ under the name fleetd's watch.sh
  # checks, starts at login, and its service's FIFO write is time-bounded so
  # it cannot hang when nothing reads. Off by default.
  claude-code-fleet-wake = evalAssert "claude-code-fleet-wake"
    (herdrUser { } { apps.ai.tools.claude-code = { enable = true; fleetWake.enable = true; }; })
    (config:
      let
        hm = hmOf config;
        exec = toString hm.systemd.user.services.fleet-new.Service.ExecStart;
      in
      hm.systemd.user.paths.fleet-new.Path.PathChanged == "%h/.claude/fleet/new"
      && hm.systemd.user.paths.fleet-new.Install.WantedBy == [ "default.target" ]
      && lib.hasInfix "/bin/timeout 2 " exec
      && lib.hasInfix "> %h/.claude/fleet/events.fifo" exec);

  claude-code-fleet-wake-off = evalAssert "claude-code-fleet-wake-off"
    (herdrUser { } { apps.ai.tools.claude-code.enable = true; })
    (config: !((hmOf config).systemd.user.paths ? fleet-new));

  # mergedSettings: the real activation step, run against a scratch home.
  # The defaults (history kept, no commit attribution) land in settings.json
  # beside Claude Code's own keys, deep-merged; the file stays a plain
  # writable file (no store link), a link to a config repo's file stays a
  # link with its target updated, and a file that is not JSON is left
  # byte-for-byte.
  claude-code-merged-settings-step =
    let
      eval = lib.nixosSystem {
        inherit specialArgs;
        modules = baseModules ++ [ baseConfig (herdrUser { } { apps.ai.tools.claude-code.enable = true; }) ];
      };
      hm = eval.config.home-manager.users.muxuser;
      step = hm.home.activation.claudeMergedSettings.data;
    in
    assert !(hm.home.file ? ".claude/settings.json");
    pkgs.runCommand "module-eval-claude-code-merged-settings-step" { nativeBuildInputs = [ pkgs.jq ]; } ''
      set -eu
      run() { "$@"; }
      fresh() { export HOME=$(mktemp -d); mkdir -p "$HOME/.claude"; }
      s() { echo "$HOME/.claude/settings.json"; }
      defaults='{"attribution":{"commit":"","pr":""},"autoCompactWindow":800000,"cleanupPeriodDays":365000,"includeCoAuthoredBy":false}'

      # absent: created with the defaults alone
      fresh; rm -r "$HOME/.claude"
      ${step}
      [ "$(jq -c -S . "$(s)")" = "$defaults" ]

      # Claude Code's own keys survive, nested ones too (a deep merge)
      fresh; echo '{"theme":"dark","cleanupPeriodDays":30,"attribution":{"x":1}}' > "$(s)"
      ${step}
      [ "$(jq -c -S . "$(s)")" = '{"attribution":{"commit":"","pr":"","x":1},"autoCompactWindow":800000,"cleanupPeriodDays":365000,"includeCoAuthoredBy":false,"theme":"dark"}' ]

      # a link into a config repo stays a link; its target is updated
      fresh; mkdir "$HOME/repo"; echo '{"model":"x"}' > "$HOME/repo/settings.json"
      ln -s "$HOME/repo/settings.json" "$(s)"
      ${step}
      [ -L "$(s)" ] && [ "$(jq -r .cleanupPeriodDays "$HOME/repo/settings.json")" = 365000 ]

      # not JSON: untouched
      fresh; echo 'not json' > "$(s)"
      # The step's text ends in a newline, so `''${step} 2>/dev/null` would leave
      # the redirect on a line of its own; a group takes the whole step.
      ( {
        ${step}
      } 2>/dev/null ) 2>leak
      [ "$(cat "$(s)")" = 'not json' ]
      # The step warns about the non-JSON file; that warning must be silenced
      # here, not left in the build log.
      if [ -s leak ]; then echo "FAIL: stderr leaked past the redirect:"; cat leak; exit 1; fi

      echo "PASS: claude-code-merged-settings-step"
      touch $out
    '';

  # usageRecord: on, the merged settings the activation step writes carry a
  # command status line whose command is a store script; off, no statusLine
  # is added. Read from the JSON the real claudeMergedSettings step merges.
  claude-code-usage-record =
    let
      on = usageRecordStep true;
      off = usageRecordStep false;
      line = (mergedOfStep on).statusLine or { };
    in
    if (line.type or null) != "command"
    then builtins.throw "FAIL: module-eval-claude-code-usage-record -- statusLine.type is not \"command\""
    else if !(lib.hasPrefix "${builtins.storeDir}/" (line.command or ""))
    then builtins.throw "FAIL: module-eval-claude-code-usage-record -- statusLine.command is not a store path"
    else if (mergedOfStep off) ? statusLine
    then builtins.throw "FAIL: module-eval-claude-code-usage-record -- statusLine added with usageRecord off"
    else pkgs.runCommand "module-eval-claude-code-usage-record" { } "echo PASS: claude-code-usage-record; touch $out";

  # usageRecord off: the real merge step leaves the settings untouched, a
  # status line the user set themselves included (C9 `-off`).
  claude-code-usage-record-off =
    let step = usageRecordStep false; in
    pkgs.runCommand "module-eval-claude-code-usage-record-off" { nativeBuildInputs = [ pkgs.jq ]; } ''
      set -eu
      run() { "$@"; }
      export HOME=$(mktemp -d); mkdir -p "$HOME/.claude"
      own='{"type":"command","command":"/home/u/own-status-line"}'
      echo "{\"statusLine\":$own}" > "$HOME/.claude/settings.json"
      ${step}
      got=$(jq -c -S .statusLine "$HOME/.claude/settings.json")
      if [ "$got" != "$(echo "$own" | jq -c -S .)" ]; then
        echo "FAIL: the user's statusLine was changed: $got"; exit 1
      fi
      echo "PASS: claude-code-usage-record-off"
      touch $out
    '';

  # usageRecord: the status-line script itself, taken from the settings.json
  # the real step writes. Each account writes usage-latest.json into its own
  # folder (CLAUDE_CONFIG_DIR), the default account into ~/.claude, never
  # /usage-latest.json; the file is rate_limits as given, written through a
  # temp file that does not outlive the run. Input without rate_limits still
  # prints a line, exits 0, and keeps the last file.
  claude-code-usage-record-step =
    let step = usageRecordStep true; in
    pkgs.runCommand "module-eval-claude-code-usage-record-step" { nativeBuildInputs = [ pkgs.jq ]; } ''
      set -eu
      run() { "$@"; }
      export HOME=$(mktemp -d)
      mkdir -p "$HOME/.claude" "$HOME/.claude-a1"
      ${step}
      cmd=$(jq -r .statusLine.command "$HOME/.claude/settings.json")
      [ -x "$cmd" ]
      rl='{"five_hour":{"used_percentage":12,"resets_at":1700000000},"seven_day":{"used_percentage":34,"resets_at":1700500000}}'
      input='{"model":{"display_name":"M"},"rate_limits":'"$rl"'}'
      # account-balance reads .rate_limits.* and .saved_at (epoch seconds).
      same() {
        [ "$(jq -c -S .rate_limits "$1")" = "$(printf '%s' "$rl" | jq -c -S .)" ] \
          && jq -e '(.saved_at | type) == "number" and .saved_at > 1700000000 and (.saved_at | floor) == .saved_at' "$1" >/dev/null
      }
      notemp() { ! ls -A "$HOME/.claude" "$HOME/.claude-a1" | grep -q 'usage-latest\.json\.'; }

      # an account: its own folder only
      shown=$(printf '%s' "$input" | CLAUDE_CONFIG_DIR="$HOME/.claude-a1" "$cmd")
      [ -n "$shown" ]
      same "$HOME/.claude-a1/usage-latest.json"
      [ ! -e "$HOME/.claude/usage-latest.json" ] && [ ! -e /usage-latest.json ]
      notemp

      # the default account: CLAUDE_CONFIG_DIR unset, so ~/.claude
      rm "$HOME/.claude-a1/usage-latest.json"
      shown=$(printf '%s' "$input" | env -u CLAUDE_CONFIG_DIR "$cmd")
      [ -n "$shown" ]
      same "$HOME/.claude/usage-latest.json"
      [ ! -e "$HOME/.claude-a1/usage-latest.json" ] && [ ! -e /usage-latest.json ]
      notemp

      # no rate_limits: a line, exit 0, the last file kept
      shown=$(printf '%s' '{"model":{"display_name":"M"}}' | env -u CLAUDE_CONFIG_DIR "$cmd")
      [ -n "$shown" ]
      same "$HOME/.claude/usage-latest.json"
      notemp

      echo "PASS: claude-code-usage-record-step"
      touch $out
    '';

  # accounts: each name is one more persisted folder of the claude-code app,
  # beside ~/.claude (not instead of it), through the same persistedDirectories
  # path as ~/.claude itself.
  claude-code-accounts-persisted = evalClauses "claude-code-accounts-persisted"
    (accountsOnPersist [ "a1" "a2" ])
    (config:
      let
        dirs = map (d: d.directory or d) config.environment.persistence."/persist".users.muxuser.directories;
      in
      {
        default = builtins.elem ".claude" dirs;
        a1 = builtins.elem ".claude-a1" dirs;
        a2 = builtins.elem ".claude-a2" dirs;
      });

  # accounts: the real activation step, run against a scratch home. The four
  # links per account resolve to $HOME/.claude/<same>; a second run changes
  # nothing; a regular settings.json already in an account folder is kept,
  # with a warning (account data is never deleted).
  claude-code-accounts-links-step =
    let
      eval = lib.nixosSystem {
        inherit specialArgs;
        modules = baseModules ++ [
          baseConfig
          (herdrUser { } { apps.ai.tools.claude-code = { enable = true; accounts = [ "a1" "a2" ]; }; })
        ];
      };
      hm = eval.config.home-manager.users.muxuser;
      step = hm.home.activation.claudeAccounts.data;
    in
    pkgs.runCommand "module-eval-claude-code-accounts-links-step" { } ''
      set -eu
      run() { "$@"; }
      export HOME=$(mktemp -d)
      mkdir -p "$HOME/.claude"
      snap() { find "$HOME" -printf '%p %y %l %T@\n' | sort; }

      ${step}
      for a in a1 a2; do
        for l in projects sessions CLAUDE.md settings.json; do
          [ -L "$HOME/.claude-$a/$l" ]
          [ "$(readlink "$HOME/.claude-$a/$l")" = "$HOME/.claude/$l" ]
        done
      done

      # idempotent: a second run changes nothing
      before=$(snap)
      ${step}
      [ "$(snap)" = "$before" ]

      # a regular settings.json is kept, and the step warns
      rm "$HOME/.claude-a1/settings.json"
      echo '{"own":true}' > "$HOME/.claude-a1/settings.json"
      {
      ${step}
      } 2> warn.log
      [ ! -L "$HOME/.claude-a1/settings.json" ]
      [ "$(cat "$HOME/.claude-a1/settings.json")" = '{"own":true}' ]
      grep -q "WARNING" warn.log

      echo "PASS: claude-code-accounts-links-step"
      touch $out
    '';

  # accounts [ ] (the default): no step, and ~/.claude is the only Claude
  # folder persisted -- today's configuration unchanged.
  claude-code-accounts-none = evalClauses "claude-code-accounts-none"
    (accountsOnPersist [ ])
    (config:
      let
        dirs = map (d: d.directory or d) config.environment.persistence."/persist".users.muxuser.directories;
      in
      {
        noStep = !((hmOf config).home.activation ? claudeAccounts);
        onlyDotClaude = builtins.filter (lib.hasPrefix ".claude") dirs == [ ".claude" ];
      });

  # accounts on impermanence: home-manager-<user> waits for each account
  # folder's persist mount (RequiresMountsFor), and a guard step runs before
  # the links step. Without it, the first switch that adds an account fills a
  # tmpfs folder the bind mount then covers.
  claude-code-accounts-mounts-ordered = evalClauses "claude-code-accounts-mounts-ordered"
    (accountsOnPersist [ "a1" "a2" ])
    (config:
      let
        req = lib.toList (config.systemd.services."home-manager-muxuser".unitConfig.RequiresMountsFor or [ ]);
        guard = (hmOf config).home.activation.claudeAccountsMounts or { };
      in
      {
        a1 = builtins.elem "/home/muxuser/.claude-a1" req;
        a2 = builtins.elem "/home/muxuser/.claude-a2" req;
        guardBeforeLinks = builtins.elem "claudeAccounts" (guard.before or [ ]);
      });

  # Its opposites: no accounts, or accounts without persistence -- no account
  # folder in RequiresMountsFor, and no guard step.
  claude-code-accounts-mounts-none =
    let
      check = name: testConfig: evalClauses name testConfig (config: {
        noReq = builtins.filter (lib.hasInfix "/.claude-")
          (lib.toList (config.systemd.services."home-manager-muxuser".unitConfig.RequiresMountsFor or [ ])) == [ ];
        noGuard = !((hmOf config).home.activation ? claudeAccountsMounts);
      });
    in
    pkgs.linkFarm "module-eval-claude-code-accounts-mounts-none" {
      none = check "claude-code-accounts-mounts-none-noaccounts" (accountsOnPersist [ ]);
      nopersist = check "claude-code-accounts-mounts-none-nopersist"
        (herdrUser { } { apps.ai.tools.claude-code = { enable = true; accounts = [ "a1" ]; }; });
    };

  # The guard and the links step, run as home-manager runs them (one shell,
  # guard first), against a scratch home, with the guard's util-linux
  # mountpoint swapped for a stub. "Not a mount point": the run fails with one
  # line naming the folder and creates no links. "A mount point": links as
  # before.
  claude-code-accounts-mount-guard =
    let
      hm = hmOf (lib.nixosSystem {
        inherit specialArgs;
        modules = baseModules ++ [ baseConfig (accountsOnPersist [ "a1" ]) ];
      }).config;
      guard = pkgs.writeText "guard" (hm.home.activation.claudeAccountsMounts.data or "exit 0");
      links = pkgs.writeText "links" hm.home.activation.claudeAccounts.data;
    in
    pkgs.runCommand "module-eval-claude-code-accounts-mount-guard" { } ''
      set -eu
      grep -Eq '/nix/store/[^ ]*util-linux[^ ]*/bin/mountpoint -q' ${guard}
      sed -E 's#/nix/store/[^ ]*/bin/mountpoint#"$STUB"#' ${guard} > guard.sh
      run() { "$@"; }
      export HOME=$(mktemp -d)
      mkdir -p "$HOME/.claude"
      printf '#!${pkgs.runtimeShell}\nexit 1\n' > no; printf '#!${pkgs.runtimeShell}\nexit 0\n' > yes
      chmod +x no yes

      STUB=$PWD/no
      if ( . ./guard.sh; . ${links} ) 2> err.log; then
        echo "FAIL: not a mount point, yet the run succeeded"; exit 1
      fi
      cat err.log
      grep -q "$HOME/.claude-a1 is not a mount point" err.log
      [ -z "$(find "$HOME" -type l)" ]

      STUB=$PWD/yes
      ( . ./guard.sh; . ${links} )
      for l in projects sessions CLAUDE.md settings.json; do
        [ "$(readlink "$HOME/.claude-a1/$l")" = "$HOME/.claude/$l" ]
      done

      echo "PASS: claude-code-accounts-mount-guard"
      touch $out
    '';

  # accounts: a name is one path segment. "../x" and "a/b" fail to evaluate,
  # and a name listed twice fails its assertion. The valid control evaluates
  # first, so "the option does not exist" cannot pass as a refusal.
  claude-code-accounts-refuses =
    let
      evalWith = accounts: (lib.nixosSystem {
        inherit specialArgs;
        modules = baseModules ++ [
          baseConfig
          (herdrUser { } { apps.ai.tools.claude-code = { enable = true; inherit accounts; }; })
        ];
      }).config;
      read = accounts: builtins.tryEval
        (builtins.deepSeq (evalWith accounts).my.users.muxuser.apps.ai.tools.claude-code.accounts true);
      control = read [ "a1" "a-2" ];
      dupFails = failing "must be unique" (evalWith [ "a1" "a1" ]) != [ ];
    in
    if !control.success then builtins.throw "FAIL: module-eval-claude-code-accounts-refuses -- valid control did not evaluate"
    else if (read [ "../x" ]).success then builtins.throw "FAIL: module-eval-claude-code-accounts-refuses -- \"../x\" accepted"
    else if (read [ "a/b" ]).success then builtins.throw "FAIL: module-eval-claude-code-accounts-refuses -- \"a/b\" accepted"
    else if !dupFails then builtins.throw "FAIL: module-eval-claude-code-accounts-refuses -- duplicate accepted"
    else pkgs.runCommand "module-eval-claude-code-accounts-refuses" { } "echo PASS: claude-code-accounts-refuses; touch $out";

  # rebuild-system / test-system / build-system, RUN against a scratch flake
  # with nixos-rebuild and sudo stubbed to print their argv. A switch builds
  # from flake.lock and nothing else: rebuild-system never adds a localInputs
  # override and refuses --local. test-system and build-system add one only
  # under --local, only for a checkout that is actually there, and say which.
  #
  # The checkout is a store path, so it exists inside the sandbox; vogix names
  # a path that does not, and must never be overridden.
  system-scripts-local-inputs =
    let
      checkout = pkgs.emptyDirectory;
      eval = lib.nixosSystem {
        inherit specialArgs;
        modules = baseModules ++ [
          baseConfig
          {
            my.system = {
              enable = true;
              localInputs = { mynixos = "${checkout}"; vogix = "/nonexistent/vogix"; };
            };
          }
        ];
      };
      script = name: lib.findFirst (p: (p.name or "") == name)
        (throw "FAIL: module-eval-system-scripts-local-inputs -- no ${name} package")
        eval.config.environment.systemPackages;
      bin = name: "${script name}/bin/${name}";
    in
    pkgs.runCommand "module-eval-system-scripts-local-inputs" { } ''
      set -u
      mkdir -p stub home/.flake
      export HOME=$PWD/home
      echo '{}' > home/.flake/flake.nix
      echo '{"nodes":{"root":{"inputs":{}}},"root":"root","version":7}' > home/.flake/flake.lock
      printf '#!${pkgs.runtimeShell}\necho "ARGV: $0 $*"\n' > stub/nixos-rebuild
      printf '#!${pkgs.runtimeShell}\nexec "$@"\n' > stub/sudo
      chmod +x stub/*
      export PATH=$PWD/stub:$PATH

      fail() { echo "FAIL: $*"; echo "--- stdout"; cat out; echo "--- stderr"; cat err; exit 1; }
      run() { rc=0; "$@" >out 2>err || rc=$?; }
      ok() { [ "$rc" = 0 ] || fail "$1 exited $rc"; grep -q "^ARGV: .*nixos-rebuild $2 --flake \.#" out || fail "$1 did not run nixos-rebuild $2"; }
      lock_only() { ! grep -q -- --override-input out || fail "$1 overrode an input"; }
      overrides() {
        grep -q "^ARGV: .*nixos-rebuild $2 --flake \.# --override-input mynixos ${checkout}$" out || fail "$1 did not override mynixos"
        grep -q "local input: mynixos -> ${checkout}" err || fail "$1 did not say what it overrode"
        ! grep -q vogix out || fail "$1 overrode an absent checkout"
      }

      run ${bin "rebuild-system"}; ok rebuild-system switch; lock_only rebuild-system
      run ${bin "rebuild-system"} --local
      [ "$rc" != 0 ] || fail "rebuild-system --local did not refuse"
      ! grep -q ARGV out || fail "rebuild-system --local still ran nixos-rebuild"
      grep -q "test-system --local" err || fail "rebuild-system --local did not point at test-system --local"

      for s in ${bin "test-system"}:test ${bin "build-system"}:build; do
        bin=''${s%:*} action=''${s##*:} name=''${bin##*/}
        run "$bin"; ok "$name" "$action"; lock_only "$name"
        run "$bin" --local; ok "$name --local" "$action"; overrides "$name --local" "$action"
        run "$bin" --local bogus
        [ "$rc" = 2 ] && grep -q Usage err || fail "$name --local did not pass the other arguments through"
      done

      echo "PASS: system-scripts-local-inputs"
      touch $out
    '';

  user-features = evalTest "user-features" {
    networking.hostName = "test-user-features";
    my.users.testuser = {
      fullName = "Test User";
      description = "test user";
      email = "testuser@example.com";
      terminal.enable = true;
      dev.enable = true;
    };
  };

  # Containers. `dev.enable = true` alone must produce a WORKING rootless podman
  # host, and evalTest's forcing would not notice any single piece of that going
  # missing -- the virtualisation.* tree is not among the four things it forces,
  # and the subid ranges only fail at runtime.
  containers-podman-default =
    let
      devUser = {
        networking.hostName = "test-containers-podman";
        my.users.devuser = {
          fullName = "Dev User";
          description = "dev user";
          email = "dev@example.com";
          dev.enable = true;
        };
      };
    in
    evalAssert "containers-podman-default" devUser
      (config:
        let
          pkgNames = map (p: p.pname or "") config.environment.systemPackages;
          runtimeNames = map (p: p.pname or "") config.virtualisation.podman.extraRuntimes;
          inherit (config.my.system.persistence) features;
          groupsOf = u: u.extraGroups or [ ];
        in
        config.my.virtualisation.containers.podman.enable
        && !config.my.virtualisation.containers.docker.enable
        && config.virtualisation.podman.enable
        && config.virtualisation.podman.dockerCompat
        # dockerSocket would symlink /run/docker.sock onto the ROOTFUL podman
        # socket, whose SocketGroup is the root-equivalent `podman` group.
        && !config.virtualisation.podman.dockerSocket.enable
        && config.virtualisation.podman.defaultNetwork.settings.dns_enabled
        && config.virtualisation.containers.enable
        && !config.virtualisation.docker.enable
        # The security point of the backend: NO account is put in a container
        # group. Both names are checked -- `podman`'s socket group is as
        # root-equivalent as `docker`'s was, so renaming would not have helped.
        && !(lib.any
          (u: lib.elem "docker" (groupsOf u) || lib.elem "podman" (groupsOf u))
          (lib.attrValues config.users.users))
        # Rootless podman fails at RUNTIME without a subordinate id range.
        # nixpkgs defaults this on for normal users, so what is asserted is that
        # mynixos left it on AND that its own eval-time guard is satisfied.
        && config.users.users.devuser.autoSubUidGidRange
        && !(lib.any (a: !a.assertion) config.assertions)
        # crun is podman's default OCI runtime and is unconditional in podman's
        # own helpersBin, so nothing here needs to place it. What IS worth
        # pinning is that we did not override extraRuntimes: that option
        # replaces rather than appends, so setting it would silently drop runc
        # as a fallback. nixpkgs' default is [ runc ].
        && runtimeNames == [ "runc" ]
        && lib.elem "crun" pkgNames
        && lib.elem ".local/share/containers" features.userDirectories
        && !(lib.elem ".docker" features.userDirectories)
        && !(lib.elem "/var/lib/docker" features.systemDirectories));

  # The other side of the enum still works, and still hands out no group: the
  # docker backend is rootless too.
  containers-docker-backend =
    let
      devUser = {
        networking.hostName = "test-containers-docker";
        my.virtualisation.containers = { docker.enable = true; podman.enable = false; };
        my.users.devuser = {
          fullName = "Dev User";
          description = "dev user";
          email = "dev@example.com";
          dev.enable = true;
        };
      };
    in
    evalAssert "containers-docker-backend" devUser
      (config:
        let
          pkgNames = map (p: p.pname or "") config.environment.systemPackages;
          inherit (config.my.system.persistence) features;
          groupsOf = u: u.extraGroups or [ ];
        in
        config.virtualisation.docker.enable
        && config.virtualisation.docker.rootless.enable
        && config.virtualisation.docker.rootless.setSocketVariable
        && !config.virtualisation.podman.enable
        && !(lib.any (u: lib.elem "docker" (groupsOf u)) (lib.attrValues config.users.users))
        && lib.elem "runc" pkgNames
        && lib.elem "/var/lib/docker" features.systemDirectories
        && lib.elem ".docker" features.userDirectories);

  # Opting out per account leaves the dev feature on and no runtime installed --
  # the two switches are genuinely independent.
  containers-opt-out = evalAssert "containers-opt-out"
    {
      networking.hostName = "test-containers-opt-out";
      my.users.devuser = {
        fullName = "Dev User";
        description = "dev user";
        email = "dev@example.com";
        dev = {
          enable = true;
          containers.enable = false;
        };
      };
    }
    (config:
      config.my.dev.enable
      && !config.virtualisation.podman.enable
      && !config.virtualisation.docker.enable
      && !config.virtualisation.containers.enable);

  # The subid guard belongs to BOTH backends: rootless dockerd needs newuidmap
  # and /etc/subuid + /etc/subgid exactly as rootless podman does. Turn the
  # range off under the docker backend and the failure must appear at EVAL time
  # -- when it lived inside the podman branch this configuration evaluated clean
  # and died on the user's first `docker run`.
  containers-docker-subid-guard =
    evalAssert "containers-docker-subid-guard"
      {
        networking.hostName = "test-containers-docker-subid";
        my.virtualisation.containers = { docker.enable = true; podman.enable = false; };
        my.users.devuser = {
          fullName = "Dev User";
          description = "dev user";
          email = "dev@example.com";
          dev.enable = true;
        };
        users.users.devuser.autoSubUidGidRange = false;
      }
      (config:
        lib.any
          (a: !a.assertion && lib.hasInfix "no subordinate uid/gid range" a.message)
          config.assertions);

  # ...and the guard is scoped to the accounts that actually run containers.
  # A second active user without dev enabled may switch the range off -- it owns
  # no container runtime, so nothing is broken and nothing must fire.
  containers-subid-guard-scoped =
    evalAssert "containers-subid-guard-scoped"
      {
        networking.hostName = "test-containers-subid-scope";
        my.users = {
          devuser = {
            fullName = "Dev User";
            description = "dev user";
            email = "dev@example.com";
            dev.enable = true;
          };
          plainuser = {
            fullName = "Plain User";
            description = "plain user";
            email = "plain@example.com";
          };
        };
        users.users.plainuser.autoSubUidGidRange = false;
      }
      (config:
        config.virtualisation.podman.enable
        && !config.users.users.plainuser.autoSubUidGidRange
        && !(lib.any (a: !a.assertion) config.assertions));

  # Test 6: Graphical option can be set
  graphical = evalTest "graphical" {
    networking.hostName = "test-graphical";
    my.graphical.enable = true;
  };

  # Test 7: Storage options evaluate
  storage = evalTest "storage" {
    networking.hostName = "test-storage";
    my.storage.impermanence.enable = false;
  };

  # Test 8: AI module evaluates
  ai = evalTest "ai" {
    networking.hostName = "test-ai";
    my.ai.enable = true;
  };

  # Test 9: Multiple modules combined
  combined = evalTest "combined" {
    networking.hostName = "test-combined";
    my = {
      system = {
        enable = true;
        hostname = "test-combined";
      };
      performance.enable = true;
      hardware = {
        cpu = "amd";
        gpu = "nvidia";
      };
      graphical.enable = true;
    };
  };

  # Hyprland config engines. One user config, two renderings: the default
  # hyprlang text and the Lua projection (`configType = "lua"`, the shape
  # Hyprland ≥0.55 accepts and 0.57 requires). Both run with theming off, so
  # what is asserted is mynixos's own fallback + infrastructure config — the
  # vogix-generated variant is covered by vogix's VM tests.
  hyprland-engine-hyprlang = evalAssert "hyprland-engine-hyprlang"
    {
      networking.hostName = "test-hypr-hyprlang";
      my = {
        theming = {
          enable = false;
          vogix.enable = false;
        };
        users.hypruser = {
          fullName = "Hypr User";
          description = "hypr";
          email = "hypr@example.com";
          graphical.enable = true;
          apps.graphical.windowManagers.hyprland = {
            enable = true;
            # No longer the default; refused on Hyprland 0.57 or later.
            configType = "hyprlang";
          };
        };
      };
    }
    (config:
      let
        hm = config.home-manager.users.hypruser;
        text = hm.xdg.configFile."hypr/hyprland.conf".text;
        refused = lib.any (a: !a.assertion && lib.hasInfix "removed hyprlang configs" a.message) config.assertions;
      in
      hm.wayland.windowManager.hyprland.configType == "hyprlang"
      && lib.hasInfix "natural_scroll=yes" text
      && lib.hasInfix "hyprctl --batch" text
      && !(hm.xdg.configFile ? "hypr/hyprland.lua")
      # Refused exactly when Hyprland is 0.57 or later.
      && refused == !(lib.versionOlder config.programs.hyprland.package.version "0.57"));

  hyprland-engine-lua = evalAssert "hyprland-engine-lua"
    {
      networking.hostName = "test-hypr-lua";
      my = {
        theming = {
          enable = false;
          vogix.enable = false;
        };
        users.hypruser = {
          fullName = "Hypr User";
          description = "hypr";
          email = "hypr@example.com";
          graphical.enable = true;
          apps.graphical.windowManagers.hyprland = {
            enable = true;
            configType = "lua";
          };
        };
      };
    }
    (config:
      let
        hm = config.home-manager.users.hypruser;
        text = hm.xdg.configFile."hypr/hyprland.lua".text;
      in
      hm.wayland.windowManager.hyprland.configType == "lua"
      # one hl.config carrying real booleans, not hyprlang "yes"/"no"
      && lib.hasInfix "hl.config({" text
      && lib.hasInfix ''["natural_scroll"] = true'' text
      && !lib.hasInfix "\"yes\"" text
      # binds go through the dispatcher translation; mouse binds are drag/resize
      && lib.hasInfix ''hl.bind("SUPER + T", (hl.dsp.exec_cmd('' text
      && lib.hasInfix "hl.dsp.window.drag()" text
      # the gap binds speak `eval`, never the legacy keyword IPC
      && lib.hasInfix "hyprctl eval" text
      && !lib.hasInfix "hyprctl --batch" text
      # curves precede animations; infra renders as hl.monitor/hl.env/
      # hl.window_rule; exec-once is the start hook with `&` stripped
      && lib.hasInfix ''hl.curve("myBezier"'' text
      && lib.hasInfix "hl.monitor({" text
      && lib.hasInfix ''hl.env("TERMINAL"'' text
      # one cursor theme with every shape: Hyprland's own env, home-manager's
      # XCURSOR_*, and the GNOME keys the portal serves
      && lib.hasInfix ''hl.env("XCURSOR_THEME", "Bibata-Modern-Classic")'' text
      && hm.home.pointerCursor.name == "Bibata-Modern-Classic"
      && hm.home.pointerCursor.size == 24
      && hm.home.sessionVariables.XCURSOR_THEME == "Bibata-Modern-Classic"
      && hm.dconf.settings."org/gnome/desktop/interface".cursor-theme == "Bibata-Modern-Classic"
      && lib.hasInfix ''["name"] = "slack-menus"'' text
      && lib.hasInfix ''hl.exec_cmd("1password --silent")'' text
      && !(hm.xdg.configFile ? "hypr/hyprland.conf"));

  # Hyprland hands WAYLAND_DISPLAY and HYPRLAND_INSTANCE_SIGNATURE to the user
  # manager from a `hyprland.start` hook that fires once per compositor
  # process. A user manager replaced under a live compositor therefore has
  # neither the environment nor the session target, and every Wayland user unit
  # dies — quickshell by qFatal, because no Qt platform plugin can initialize.
  # These two units are what makes the session recoverable, and each of the
  # asserted properties is load-bearing rather than incidental:
  #
  #   - the env import is ordered before BOTH session targets, so it lands
  #     ahead of anything that needs a display;
  #   - it must NOT set RemainAfterExit, or it would go "active (exited)" and
  #     never run again — reintroducing the once-only behaviour it exists to
  #     fix;
  #   - the recovery unit hangs off default.target and must never be reachable
  #     from the session target, or raising the target would wait on a job
  #     whose whole purpose is to raise the target.
  hyprland-session-recovery = evalAssert "hyprland-session-recovery"
    {
      networking.hostName = "test-hypr-session";
      my = {
        theming = {
          enable = false;
          vogix.enable = false;
        };
        users.hypruser = {
          fullName = "Hypr User";
          description = "hypr";
          email = "hypr@example.com";
          graphical.enable = true;
          apps.graphical.windowManagers.hyprland.enable = true;
        };
      };
    }
    (config:
      let
        units = config.home-manager.users.hypruser.systemd.user.services;
        env = units.hyprland-session-env;
        recover = units.hyprland-session-recover;
      in
      builtins.elem "graphical-session-pre.target" env.Unit.Before
      && builtins.elem "graphical-session.target" env.Unit.Before
      && env.Install.WantedBy == [ "graphical-session-pre.target" ]
      && env.Service.Type == "oneshot"
      && !(env.Service ? RemainAfterExit)
      && recover.Install.WantedBy == [ "default.target" ]
      && recover.Service.Type == "oneshot");

  # The vogix-generated variant of the Lua projection: with theming on, the
  # binds come from vogix's behavior overlay (rendered through its Lua
  # generator) and mynixos contributes only infrastructure — whose window
  # rules must still be concatenated with vogix's, not clobber them.
  hyprland-engine-lua-vogix = evalAssert "hyprland-engine-lua-vogix"
    {
      networking.hostName = "test-hypr-lua-vogix";
      my = {
        theming = {
          enable = true;
          vogix.enable = true;
        };
        users.hypruser = {
          fullName = "Hypr User";
          description = "hypr";
          email = "hypr@example.com";
          graphical.enable = true;
          apps.graphical.windowManagers.hyprland = {
            enable = true;
            configType = "lua";
          };
        };
      };
    }
    (config:
      let
        hm = config.home-manager.users.hypruser;
        text = hm.xdg.configFile."hypr/hyprland.lua".text;
      in
      hm.wayland.windowManager.hyprland.configType == "lua"
      # vogix overlay binds render through the dispatcher translation
      && lib.hasInfix ''hl.bind("SUPER + return", (hl.dsp.exec_cmd("$TERMINAL"'' text
      && lib.hasInfix "hl.dsp.window.drag()" text
      # the gap binds are vogix's dialect-aware CLI, not raw hyprctl keyword
      && lib.hasInfix "vogix hypr keyword" text
      && !lib.hasInfix "hyprctl --batch" text
      # one hl.config with real booleans
      && lib.hasInfix "hl.config({" text
      && lib.hasInfix ''["natural_scroll"] = true'' text
      # mynixos infra rules ride beside the vogix-generated ones
      && lib.hasInfix ''["name"] = "slack-menus"'' text
      && lib.hasInfix ''hl.env("TERMINAL"'' text);

  # The graphical.shell selection. waybar is DELETED — the fleet's shell is
  # the vogix desktop — so what these pin is: the default resolves through
  # the theming gates to vogix (bar unit present, contract generated), "none"
  # really means no shell, and nothing anywhere still configures waybar.
  graphical-shell-default-is-vogix = evalAssert "graphical-shell-default-is-vogix"
    {
      networking.hostName = "test-shell-default";
      my.users.shelluser = {
        fullName = "Shell User";
        description = "shell";
        email = "shell@example.com";
        graphical.enable = true;
      };
    }
    (config:
      let hm = config.home-manager.users.shelluser; in
      config.my.users.shelluser.graphical.shell == "vogix"
      && hm.programs.vogix.desktop.enable
      && (hm.systemd.user.services ? vogix-desktop)
      && !(hm.programs.waybar.enable or false));

  graphical-shell-vogix = evalAssert "graphical-shell-vogix"
    {
      networking.hostName = "test-shell-vogix";
      my = {
        theming = {
          enable = true;
          vogix.enable = true;
        };
        users.shelluser = {
          fullName = "Shell User";
          description = "shell";
          email = "shell@example.com";
          graphical = {
            enable = true;
            shell = "vogix";
          };
        };
      };
    }
    (config:
      let hm = config.home-manager.users.shelluser; in
      hm.programs.vogix.desktop.enable
      && !(hm.programs.waybar.enable or false)
      && (hm.systemd.user.services ? vogix-desktop)
      && hm.programs.vogix."vogix-desktop".enable
      # The lock surface: the person's idle policy reaches the shell, the
      # lock hook binds into lock.target/sleep.target, PAM + the logind
      # bridge come from vogix's NixOS module, and $LOCKER resolves to the
      # shell's own locker through getExe (wrapper packages have no pname).
      && hm.programs.vogix.desktop.idle.lock == 600
      && (hm.systemd.user.services ? vogix-lock)
      && config.security.pam.services ? vogix-lock
      && config.services.systemd-lock-handler.enable
      && lib.hasSuffix "/bin/vogix-lock" hm.home.sessionVariables.LOCKER
      # The launcher surface: $LAUNCHER resolves to the shell's launcher
      # (walker/elephant are deleted; no elephant backend unit remains).
      && hm.programs.vogix.desktop.launcher.enable
      && hm.programs.vogix.desktop.power.enable
      && lib.hasSuffix "/bin/vogix-launcher" hm.home.sessionVariables.LAUNCHER
      && !(hm.systemd.user.services ? elephant)
      && !(hm.systemd.user.services ? walker)
      # The greeter surface: with theming on, the login defaults to the
      # vogix SDDM greeter under the Hyprland Lua compositor config; the
      # runtime-follow drop zone exists and this user's theme switches
      # sync into it; U2F stays off at the greeter (SDDM cannot answer the
      # interactive pam_u2f prompt).
      && config.my.environment.login.backend == "sddm"
      && config.my.environment.login.look == "vogix"
      && config.services.displayManager.sddm.enable
      && config.services.displayManager.sddm.wayland.enable
      && config.services.displayManager.sddm.theme == "vogix"
      && lib.hasInfix "/etc/vogix/greeter/hyprland.lua"
        config.services.displayManager.sddm.wayland.compositorCommand
      && (config.environment.etc ? "vogix/greeter/hyprland.lua")
      && lib.hasInfix "disable_hyprland_logo"
        config.environment.etc."vogix/greeter/hyprland.lua".text
      && builtins.elem "d /var/lib/vogix/greeter 2775 root vogix -"
        config.systemd.tmpfiles.rules
      && hm.programs.vogix.greeter.sync
      && hm.programs.vogix.themeApply ? greeter
      && !config.security.pam.services.sddm.u2fAuth
      # nixpkgs' `substack login` is replaced with a direct auth stack:
      # unix present, no substack. Without the yubico module there is no
      # u2f rule at all (this host carries none).
      && config.security.pam.services.sddm.rules.auth ? unix
      && !(config.security.pam.services.sddm.rules.auth ? login)
      && !(config.security.pam.services.sddm.rules.auth ? u2f)
      # The boot splash follows the palette: the vogix plymouth theme is
      # selected and its package staged.
      && config.boot.plymouth.theme == "vogix"
      && lib.any (p: lib.hasInfix "vogix-plymouth" p.name) config.boot.plymouth.themePackages);

  # Notification actions send an xdg-activation token only from vogix's
  # patched quickshell (vogix.lib.quickshellPatched: nixpkgs' 0.3.2 plus two
  # patches, marked passthru.vogixActivationToken). The vogix desktop unit
  # runs programs.quickshell.package, so that is the package that must be
  # the patched build — and it must be the one home-manager installs. It
  # arrives through the per-user nixpkgs.overlays in my/theming/vogix
  # (useGlobalPkgs is off, so the system overlay alone would not reach it);
  # this guards that path.
  graphical-shell-quickshell-patched = evalClauses "graphical-shell-quickshell-patched"
    {
      networking.hostName = "test-shell-quickshell";
      my.users.shelluser = {
        fullName = "Shell User";
        description = "shell";
        email = "shell@example.com";
        graphical.enable = true;
      };
    }
    (config:
      let
        hm = config.home-manager.users.shelluser;
        qs = hm.programs.quickshell.package;
      in
      {
        quickshell-enabled = hm.programs.quickshell.enable;
        quickshell-patched = qs.passthru.vogixActivationToken or false;
        quickshell-installed = lib.any (p: (p.drvPath or null) == qs.drvPath) hm.home.packages;
        desktop-unit-runs-it = lib.hasInfix
          (builtins.unsafeDiscardStringContext "${qs}/bin/qs ")
          (builtins.unsafeDiscardStringContext
            (toString hm.systemd.user.services.vogix-desktop.Service.ExecStart));
      });

  # The machine surfaces on a yoga-shaped host: the Kraken ring and the
  # Keychron backlight come from mynixos's hardware options, the DRAM from
  # vogix's own option, and all three follow the machine owner's published
  # palette through the owner units. The owner is the first user, by name,
  # whose theming.vogix is on, so alice, who opts out, never owns them. The
  # host is impermanent, with the vogix greeter, so both vogix drop zones
  # are persisted.
  vogix-machine-surfaces = evalClauses "vogix-machine-surfaces"
    {
      networking.hostName = "test-vogix-machine";
      fileSystems."/persist" = {
        device = "/dev/disk/by-label/persist";
        fsType = "ext4";
        neededForBoot = true;
      };
      my = {
        storage.impermanence.enable = true;
        theming = {
          enable = true;
          vogix.enable = true;
        };
        hardware = {
          cooling.nzxt.kraken-elite-rgb.elite-240-rgb.enable = true;
          peripherals.keychron.k2-he.enable = true;
        };
        users = {
          alice = {
            fullName = "Alice";
            description = "alice";
            email = "alice@example.com";
            theming.vogix.enable = false;
          };
          shelluser = {
            fullName = "Shell User";
            description = "shell";
            email = "shell@example.com";
            graphical.enable = true;
          };
        };
      };
      vogix.hardware.dram-rgb.enable = true;
    }
    (config:
      let
        etc = config.environment.etc;
        # fromJSON refuses string context, and the Kraken argv carries
        # liquidctl's store path.
        machine = builtins.fromJSON
          (builtins.unsafeDiscardStringContext (etc."vogix/machine.json".text or "{}"));
        inherit (config.systemd) services;
        openrgbOwner = services.vogix-openrgb or { };
        krakenRing = machine.devices.kraken-ring.provider.command or { };

        persisted = config.environment.persistence."/persist".directories;
        persistedAt = path: map (d: { inherit (d) user group mode; })
          (builtins.filter (d: d.dirPath == path) persisted);
        # The mode, owner and group each tmpfiles `d` rule gives its path, in
        # either tmpfiles form; "-" leaves a field unset.
        ruleFields = rule: builtins.filter (w: builtins.isString w && w != "")
          (builtins.split "[[:space:]]+" rule);
        dRules = map (f: { path = builtins.elemAt f 1; fields = lib.sublist 2 3 f; })
          (builtins.filter (f: builtins.length f >= 5 && builtins.head f == "d")
            (map ruleFields config.systemd.tmpfiles.rules))
        ++ lib.concatMap
          (paths: lib.mapAttrsToList
            (path: types: {
              inherit path;
              fields = [ (types.d.mode or "-") (types.d.user or "-") (types.d.group or "-") ];
            })
            (lib.filterAttrs (_: types: types ? d) paths))
          (builtins.attrValues config.systemd.tmpfiles.settings);
        persistedWithRule = builtins.filter
          (d: builtins.any (r: r.path == d.dirPath) dRules)
          persisted;
        agrees = d: r: builtins.all ({ fst, snd }: fst == "-" || fst == snd)
          (lib.zipLists r.fields [ d.mode d.user d.group ]);
      in
      {
        machineJsonRendered = etc ? "vogix/machine.json";
        ownerFirstVogixUser = (machine.owner or null) == "shelluser";
        deviceSet = builtins.attrNames (machine.devices or { })
          == [ "dram-rgb" "keychron-k2-he" "kraken-ring" ];
        krakenRingHotplug = (krakenRing.hotplug.hidraw or null)
          == { vendorId = "1e71"; productId = "3012"; };
        krakenRingLiquidctl = lib.hasSuffix "/bin/liquidctl" (builtins.head (krakenRing.argv or [ "" ]));
        keychronOpenrgb = (machine.devices.keychron-k2-he.provider.openrgb or null)
          == { nameContains = "Keychron K2 HE"; mode = "Static"; };
        # The K2 HE is registered with OpenRGB once, by vogix.
        keychronRegisteredByVogix = config.vogix.openrgb.qmkDevices
          == [{ name = "Keychron K2 HE"; vid = "0x3434"; pid = "0x0E20"; }]
          && config.my.theming.openrgb.qmkDevices == [ ];
        dramOpenrgb = (machine.devices.dram-rgb.provider.openrgb or null)
          == { nameContains = "ENE DRAM"; mode = "Static"; };
        openrgbEndpointPort = (machine.openrgb.port or null)
          == config.services.hardware.openrgb.server.port;
        # Every start of the server starts the OpenRGB owner once the server
        # listens (Wants= from wantedBy, After=), BindsTo= stops it with the
        # server, and a switch restarts it only after the new machine.json is
        # installed. It restarts on failure but a 78, which Upholds= would
        # override by starting it again whatever it exited with.
        openrgbOwnerBound = (openrgbOwner.bindsTo or null) == [ "openrgb.service" ]
          && (openrgbOwner.after or null) == [ "openrgb.service" ]
          && (openrgbOwner.wantedBy or null) == [ "openrgb.service" ]
          && (openrgbOwner.upheldBy or null) == [ ]
          && (openrgbOwner.serviceConfig.Restart or null) == "on-failure"
          && (openrgbOwner.serviceConfig.RestartPreventExitStatus or null) == 78
          && (openrgbOwner.stopIfChanged or true) == false;
        openrgbServerNotifies = (services.openrgb.serviceConfig.Type or null) == "notify"
          && (config.services.hardware.openrgb.package.passthru.vogixReadiness or false);
        consoleBeforeLogins = (services.vogix-machine.before or null)
          == [ "systemd-user-sessions.service" ];
        reappliedAfterSuspend = builtins.elem "suspend.target"
          (services.vogix-machine-resume.wantedBy or [ ]);
        # mynixos gives each account its own group.
        dropZoneOwned = builtins.elem "d /var/lib/vogix/machine 0755 shelluser shelluser -"
          config.systemd.tmpfiles.rules;
        # A switch mounts the persistent copy over the directory tmpfiles
        # created, so the copy is created owned by the owner.
        dropZonePersisted = persistedAt "/var/lib/vogix/machine"
          == [{ user = "shelluser"; group = "shelluser"; mode = "0755"; }];
        greeterZonePersisted = persistedAt "/var/lib/vogix/greeter"
          == [{ user = "root"; group = "vogix"; mode = "2775"; }];
        # Every persisted system directory that a tmpfiles `d` rule creates
        # has its persistent copy created with that rule's mode, owner and
        # group; both vogix zones are among them.
        persistedAsTmpfiles = lib.subtractLists (map (d: d.dirPath) persistedWithRule)
          [ "/var/lib/vogix/greeter" "/var/lib/vogix/machine" ] == [ ]
        && builtins.all
          (d: builtins.all (agrees d) (builtins.filter (r: r.path == d.dirPath) dRules))
          persistedWithRule;
        # The devices are the owner units' alone: the owner's apply hooks
        # hold the color-scheme write and the greeter sync, and no device.
        ownerHooksNoDevices = builtins.attrNames
          config.home-manager.users.shelluser.programs.vogix.themeApply == [ "color-scheme" "greeter" ];
        # vogix refuses an owner outside its users, devices without an owner,
        # a command outside the store and an OpenRGB build without readiness.
        assertionsHold = lib.all (a: a.assertion) config.assertions;
      });

  # With theming on but every user opted out of vogix there is no machine
  # owner, so there are no machine surfaces and no drop zone to persist. The
  # host has the Kraken and the K2 HE: their hardware support stays, their
  # devices do not.
  vogix-machine-no-owner = evalClauses "vogix-machine-no-owner"
    {
      networking.hostName = "test-vogix-no-owner";
      my = {
        theming = {
          enable = true;
          vogix.enable = true;
        };
        hardware = {
          cooling.nzxt.kraken-elite-rgb.elite-240-rgb.enable = true;
          peripherals.keychron.k2-he.enable = true;
        };
        users.alice = {
          fullName = "Alice";
          description = "alice";
          email = "alice@example.com";
          theming.vogix.enable = false;
        };
      };
    }
    (config: {
      noOwner = config.vogix.machine.owner == null;
      noMachineJson = !(config.environment.etc ? "vogix/machine.json");
      noOwnerUnits = !(config.systemd.services ? vogix-machine)
        && !(config.systemd.services ? vogix-machine-resume);
      dropZoneNotPersisted = !(builtins.elem "/var/lib/vogix/machine"
        (map (d: d.directory or d) config.my.system.persistence.features.systemDirectories));
      noDevices = config.vogix.hardware.devices == { };
      # vogix's Kraken module stays on without its ring.
      krakenWithoutRing = config.vogix.hardware.kraken-elite.enable
        && !config.vogix.hardware.kraken-elite.rgb.ring.enable
        && builtins.elem "nzxt_kraken3" config.boot.kernelModules;
      # The K2 HE keeps its udev rules and is registered with OpenRGB once,
      # by mynixos.
      k2heSupported = !config.vogix.hardware.keychron-k2-he.enable
        && lib.any (p: lib.hasInfix "keychron-k2-he-udev-rules" (p.name or "")) config.services.udev.packages
        && config.my.theming.openrgb.qmkDevices
        == [{ name = "Keychron K2 HE"; vid = "0x3434"; pid = "0x0E20"; }]
        && config.vogix.openrgb.qmkDevices == [ ];
      assertionsHold = lib.all (a: a.assertion) config.assertions;
    });

  # The theme's session side: login shells run nothing from vogix, the
  # restore runs once per graphical session that the Hyprland session
  # raises, and the user's apply hooks (the greeter sync) render as
  # [hooks."<name>"], never as the removed [hardware] tables.
  vogix-session-restore = evalClauses "vogix-session-restore"
    {
      networking.hostName = "test-vogix-restore";
      my = {
        theming = {
          enable = true;
          vogix.enable = true;
        };
        users.shelluser = {
          fullName = "Shell User";
          description = "shell";
          email = "shell@example.com";
          graphical.enable = true;
        };
      };
    }
    (config:
      let
        hm = config.home-manager.users.shelluser;
        restore = hm.systemd.user.services.vogix-theme-restore or null;
        loginTexts = [
          hm.programs.bash.profileExtra
          hm.programs.zsh.profileExtra
          hm.programs.zsh.loginExtra
          hm.programs.fish.loginShellInit
          config.environment.loginShellInit
        ];
        activation = hm.home.activation.vogixSetup.data;
      in
      {
        loginShellsRunNoVogix = !(lib.any (lib.hasInfix "bin/vogix") loginTexts);
        compositorRunsNoRefresh = !(lib.hasInfix "theme refresh" hm.xdg.configFile."hypr/hyprland.lua".text);
        restoreUnit = restore != null
          && restore.Service.Type == "oneshot"
          && !(restore.Service ? RemainAfterExit)
          && lib.toList restore.Service.ExecStart
          == [ "${hm.programs.vogix.package}/bin/vogix theme refresh" ]
          && builtins.elem "graphical-session.target" restore.Unit.After
          && builtins.elem "graphical-session.target" restore.Install.WantedBy;
        sessionRaisesTarget = builtins.elem "graphical-session.target"
          (hm.systemd.user.targets.hyprland-session.Unit.BindsTo or [ ]);
        hooksTables = lib.hasInfix ''[hooks."greeter"]'' activation
          && !(lib.hasInfix "[hardware" activation);
      });

  # input.inputMethod = "fcitx5": the server is a user unit raised with the
  # graphical session, on the Wayland frontend; mynixos owns classicui.conf
  # alone (Theme=vogix for a vogix user), never the whole ~/.config/fcitx5,
  # which stays fcitx5's and persisted. A user who did not ask gets nothing.
  input-method-fcitx5 = evalClauses "input-method-fcitx5"
    {
      networking.hostName = "test-fcitx5";
      my = {
        theming = {
          enable = true;
          vogix.enable = true;
        };
        users.shelluser = {
          fullName = "Shell User";
          description = "shell";
          email = "shell@example.com";
          graphical.enable = true;
          input.inputMethod.type = "fcitx5";
        };
        users.other = {
          fullName = "Other User";
          description = "other";
          email = "other@example.com";
          graphical.enable = true;
        };
      };
    }
    (config:
      let
        hm = config.home-manager.users.shelluser;
        unit = hm.systemd.user.services.fcitx5-daemon or null;
        classicui = hm.xdg.configFile."fcitx5/conf/classicui.conf".text or "";
        userDirs = config.my.system.persistence.features.userDirectories;
      in
      {
        fcitx5Type = hm.i18n.inputMethod.enable && hm.i18n.inputMethod.type == "fcitx5";
        waylandFrontend = hm.i18n.inputMethod.fcitx5.waylandFrontend
          && !(hm.home.sessionVariables ? GTK_IM_MODULE)
          && !(hm.home.sessionVariables ? QT_IM_MODULE);
        unitWithSession = unit != null
          && builtins.elem "graphical-session.target" unit.Install.WantedBy;
        themeIsVogix = lib.hasInfix "Theme=vogix" classicui
          && lib.hasInfix "UseDarkTheme=False" classicui
          && lib.hasInfix ''Font="Fira Code Nerd Font 16"'' classicui;
        noTriggerKeys = lib.hasInfix "[Hotkey/TriggerKeys]"
          (hm.xdg.configFile."fcitx5/config".text or "");
        restartsOnConfig = builtins.length (unit.Unit.X-Restart-Triggers or [ ]) == 4;
        noTrayItem = lib.hasInfix "0=notificationitem"
          (hm.xdg.configFile."fcitx5/config".text or "");
        xkbNotOverridden = lib.all
          (f: lib.hasInfix "Allow Overriding System XKB Settings=False" (hm.xdg.configFile."fcitx5/conf/${f}.conf".text or ""))
          [ "wayland" "xcb" ];
        configDirNotLinked = !(hm.xdg.configFile ? fcitx5);
        persisted = builtins.elem ".config/fcitx5" userDirs
          && builtins.elem ".local/share/fcitx5" userDirs;
        otherUntouched = !config.home-manager.users.other.i18n.inputMethod.enable;
        vogixThemesIt = hm.programs.vogix.fcitx5.enable
          && !config.home-manager.users.other.programs.vogix.fcitx5.enable;
      });

  # my.system.etcNixos.link: /etc/nixos leaves the SYSTEM persistence list and
  # its target does not enter it; the link is an activation step that can only
  # make, re-point or replace an empty directory (no tmpfiles L+, no rm).
  etc-nixos-link = evalClauses "etc-nixos-link"
    {
      networking.hostName = "test-etc-nixos-link";
      fileSystems."/persist" = {
        device = "/dev/disk/by-label/persist";
        fsType = "ext4";
        neededForBoot = true;
      };
      my = {
        storage.impermanence.enable = true;
        system.etcNixos.link = "/home/alice/Code/flake";
      };
    }
    (config:
      let
        dirs = map (d: d.directory or d) config.environment.persistence."/persist".directories;
        script = config.system.activationScripts.etcNixosLink.text;
      in
      {
        notPersisted = !(builtins.elem "/etc/nixos" dirs);
        targetNotPersisted = !(lib.any (lib.hasPrefix "/home") dirs);
        linkStep = lib.hasInfix "/home/alice/Code/flake" script
          && lib.hasInfix "rmdir /etc/nixos" script
          && !(lib.hasInfix "rm -" script);
        noTmpfilesLink = !(lib.any (lib.hasInfix "/etc/nixos") config.systemd.tmpfiles.rules);
      });

  # What a tmpfs root would otherwise lose at every boot: the machine id
  # (journald's per-boot logs), NetworkManager's saved networks (private) and
  # secret_key, the screenshot directory swappy saves to, and the state of
  # boltd/fwupd/OpenRGB when they run. A service that is off adds nothing.
  impermanence-boot-state = evalClauses "impermanence-boot-state"
    {
      networking.hostName = "test-impermanence-boot-state";
      fileSystems."/persist" = {
        device = "/dev/disk/by-label/persist";
        fsType = "ext4";
        neededForBoot = true;
      };
      networking.networkmanager.enable = true;
      services.hardware.bolt.enable = true;
      services.fwupd.enable = false;
      my = {
        storage.impermanence.enable = true;
        users.shelluser = {
          fullName = "Shell User";
          description = "shell";
          email = "shell@example.com";
          graphical.enable = true;
        };
      };
    }
    (config:
      let
        p = config.environment.persistence."/persist";
        dirs = map (d: d.directory or d) p.directories;
        nmConnections = lib.findFirst (d: (d.directory or null) == "/etc/NetworkManager/system-connections") null p.directories;
        userDirs = map (d: d.directory or d) p.users.shelluser.directories;
      in
      {
        machineId = builtins.elem "/etc/machine-id" (map (f: f.file or f) p.files);
        # The live switch that introduces it adopts an identical id rather
        # than failing, before impermanence's own pass over its files.
        machineIdAdopted = config.system.activationScripts ? machineIdAdopt
          && builtins.elem "machineIdAdopt" config.system.activationScripts.persist-files.deps
          # and clears the failed state of impermanence's own unit, by its real name
          && lib.any
          (n: lib.hasPrefix "persist-persist-etc-machine" n
            && lib.hasInfix "${n}.service" config.system.activationScripts.machineIdAdopt.text)
          (builtins.attrNames config.systemd.services);
        networkManager = config.networking.networkmanager.enable
          && builtins.elem "/var/lib/NetworkManager" dirs
          && nmConnections != null && nmConnections.mode == "0700";
        boltd = builtins.elem "/var/lib/boltd" dirs;
        fwupdOffNotPersisted = !(builtins.elem "/var/lib/fwupd" dirs);
        screenshots = builtins.elem "Pictures/screenshots" userDirs;
      });

  # The audit watch on /etc/nixos follows the link decision: dropped when
  # /etc/nixos is a link to a user's checkout, kept when it is a directory.
  etc-nixos-audit-linked = evalClauses "etc-nixos-audit-linked"
    {
      networking.hostName = "test-etc-nixos-audit-linked";
      my = {
        security = {
          enable = true;
          auditRules.enable = true;
        };
        system.etcNixos.link = "/home/alice/Code/flake";
      };
    }
    (config: {
      noNixosWatch = !(lib.any (lib.hasInfix "/etc/nixos") config.security.audit.rules);
      otherWatchesKept = builtins.elem "-w /boot/ -p wa -k boot" config.security.audit.rules;
    });

  # S3: the locked rule set loads once at boot. A switch must not restart the
  # loader (an immutable set can't be reloaded), so the unit runs but never
  # restarts; the upstream augenrules unit stays off.
  audit-rules-load-at-boot = evalClauses "audit-rules-load-at-boot"
    {
      networking.hostName = "test-audit-rules-load-at-boot";
      my.security = {
        enable = true;
        auditRules.enable = true;
      };
    }
    (config: {
      locked = config.security.audit.enable == "lock";
      loaderOn = config.systemd.services.audit-rules-nixos.enable;
      atBoot = builtins.elem "sysinit.target" config.systemd.services.audit-rules-nixos.wantedBy;
      notOnSwitch = !config.systemd.services.audit-rules-nixos.restartIfChanged;
      afterPaths = lib.all (u: builtins.elem u config.systemd.services.audit-rules-nixos.after)
        [ "local-fs.target" "systemd-tmpfiles-setup.service" ];
      watchedDirExists = builtins.elem "d /etc/nixos 0755 root root -" config.systemd.tmpfiles.rules;
      augenrulesOff = !(config.systemd.services.audit-rules.enable or false);
    });

  # Its opposite: without auditRules there is no audit loader at all.
  audit-rules-off = evalClauses "audit-rules-off"
    {
      networking.hostName = "test-audit-rules-off";
      my.security.enable = true;
    }
    (config: {
      notLocked = config.security.audit.enable != "lock";
      noRules = config.security.audit.rules == [ ];
    });

  etc-nixos-audit-default = evalClauses "etc-nixos-audit-default"
    {
      networking.hostName = "test-etc-nixos-audit-default";
      my.security = {
        enable = true;
        auditRules.enable = true;
      };
    }
    (config: {
      nixosWatch = builtins.elem "-w /etc/nixos/ -p wa -k nixos_config" config.security.audit.rules;
    });

  # Without the option, today's behaviour: /etc/nixos persisted, no link step.
  etc-nixos-default = evalClauses "etc-nixos-default"
    {
      networking.hostName = "test-etc-nixos-default";
      fileSystems."/persist" = {
        device = "/dev/disk/by-label/persist";
        fsType = "ext4";
        neededForBoot = true;
      };
      my.storage.impermanence.enable = true;
    }
    (config: {
      persisted = builtins.elem "/etc/nixos"
        (map (d: d.directory or d) config.environment.persistence."/persist".directories);
      noLinkStep = !(config.system.activationScripts ? etcNixosLink);
    });

  # The link step itself, run against a scratch directory in place of /etc:
  # absent and empty become the link, a link is re-pointed, and a populated
  # directory is left exactly as it was.
  etc-nixos-link-step =
    let
      eval = lib.nixosSystem {
        inherit specialArgs;
        modules = baseModules ++ [
          baseConfig
          {
            networking.hostName = "test-etc-nixos-link-step";
            my.system.etcNixos.link = "/home/alice/Code/flake";
          }
        ];
      };
      # escapeShellArg leaves a plain path unquoted; the scratch target is
      # swapped in double-quoted, so it expands.
      step = target: builtins.replaceStrings [ "/etc/nixos" "/home/alice/Code/flake" ] [ "$root/etc/nixos" "\"${target}\"" ]
        eval.config.system.activationScripts.etcNixosLink.text;
    in
    pkgs.runCommand "module-eval-etc-nixos-link-step" { } ''
      set -eu
      fresh() { root=$(mktemp -d); mkdir -p "$root/etc" "$root/flake"; }

      # absent
      fresh
      ${step "$root/flake"}
      [ "$(readlink "$root/etc/nixos")" = "$root/flake" ]

      # already a link elsewhere: re-pointed, old target intact
      fresh; mkdir "$root/old"; touch "$root/old/keep"; ln -s "$root/old" "$root/etc/nixos"
      ${step "$root/flake"}
      [ "$(readlink "$root/etc/nixos")" = "$root/flake" ] && [ -e "$root/old/keep" ]

      # empty directory
      fresh; mkdir "$root/etc/nixos"
      ${step "$root/flake"}
      [ "$(readlink "$root/etc/nixos")" = "$root/flake" ]

      # populated directory: untouched
      fresh; mkdir "$root/etc/nixos"; echo data > "$root/etc/nixos/flake.nix"
      ${step "$root/flake"} 2>/dev/null
      [ ! -L "$root/etc/nixos" ] && [ "$(cat "$root/etc/nixos/flake.nix")" = data ]

      echo "PASS: etc-nixos-link-step"
      touch $out
    '';

  # The guard itself: a selected terminal that is not in the user's packages
  # is refused, naming the user and the terminal -- the shape of b1b7c9f,
  # where Super+Return ran a program nothing had installed.
  terminal-not-installed-refused = evalClauses "terminal-not-installed-refused"
    {
      networking.hostName = "test-terminal-guard";
      my.users.shelluser = {
        fullName = "Shell User";
        description = "shell";
        email = "shell@example.com";
        graphical.enable = true;
      };
      home-manager.users.shelluser.home.packages = lib.mkForce [ ];
    }
    (config:
      let failed = builtins.filter (a: !a.assertion) config.assertions;
      in {
        refused = lib.any
          (a: lib.hasInfix "environment.TERMINAL selects baud" a.message
            && lib.hasInfix "shelluser" a.message)
          failed;
      });

  # baud is the default terminal: the selector picks it, wezterm stays as the
  # fallback on Super+Shift+Return -- ADDED to vogix's keymap, not replacing
  # it -- and Terminal=true apps open in it. A user who selects wezterm gets
  # wezterm everywhere and no fallback binding.
  baud-default-terminal = evalClauses "baud-default-terminal"
    {
      networking.hostName = "test-baud-default";
      my = {
        theming = {
          enable = true;
          vogix.enable = true;
        };
        users.shelluser = {
          fullName = "Shell User";
          description = "shell";
          email = "shell@example.com";
          graphical.enable = true;
        };
        users.other = {
          fullName = "Other User";
          description = "other";
          email = "other@example.com";
          graphical.enable = true;
          environment.TERMINAL = pkgs.wezterm;
        };
      };
    }
    (config:
      let
        hm = config.home-manager.users.shelluser;
        other = config.home-manager.users.other;
        appBinds = u: u.programs.vogix.behavior.modes.app.bindings;
      in
      {
        baudSelected = config.my.users.shelluser.environment.TERMINAL.package.pname == "baud";
        # On PATH, not just named in $TERMINAL (b1b7c9f selected baud and
        # installed nothing); and the guard against that holds.
        baudInstalled = lib.any (p: (p.pname or "") == "baud") hm.home.packages;
        terminalGuardHolds = lib.all (a: a.assertion) config.assertions;
        terminalVar = lib.hasSuffix "/bin/baud" hm.home.sessionVariables.TERMINAL;
        weztermFallbackInstalled = hm.programs.wezterm.enable;
        fallbackBind = (appBinds hm).terminalFallback.key == "super + shift + return"
          && (appBinds hm).terminalFallback.action == "exec, wezterm";
        vogixKeymapKept = (appBinds hm).terminal.action == "exec, $TERMINAL";
        terminalExec = hm.xdg.configFile."xdg-terminals.list".text == "org.baud.terminal.desktop\n";
        optOutIsWezterm = lib.hasSuffix "/bin/wezterm" other.home.sessionVariables.TERMINAL
          && !((appBinds other) ? terminalFallback)
          && other.xdg.configFile."xdg-terminals.list".text == "org.wezfurlong.wezterm.desktop\n";
      });

  # apps.graphical.terminals.baud: a vogix user's config.toml names vogix's
  # two theme links, replaces baud's first-launch file, and itself installs
  # nothing (the TERMINAL selector does). With nothing to say -- no vogix, no settings --
  # no file is written and baud's own stays.
  baud-config = evalClauses "baud-config"
    {
      networking.hostName = "test-baud";
      my = {
        theming = {
          enable = true;
          vogix.enable = true;
        };
        users = {
          shelluser = {
            fullName = "Shell User";
            description = "shell";
            email = "shell@example.com";
            graphical.enable = true;
            apps.graphical.terminals.baud = {
              enable = true;
              settings.screen.notifications = "on";
            };
          };
          other = {
            fullName = "Other User";
            description = "other";
            email = "other@example.com";
            graphical.enable = true;
            theming.vogix.enable = false;
            apps.graphical.terminals.baud.enable = true;
            # baud's config without baud as the terminal: the config module
            # itself installs nothing (only the TERMINAL selector installs).
            environment.TERMINAL = pkgs.wezterm;
          };
          # Says nothing about baud: a graphical vogix user gets it by default.
          defaulted = {
            fullName = "Defaulted User";
            description = "defaulted";
            email = "defaulted@example.com";
            graphical.enable = true;
          };
        };
      };
    }
    (config:
      let
        file = config.home-manager.users.shelluser.xdg.configFile."baud/config.toml";
        defaulted = config.home-manager.users.defaulted;
        # The generator's input, carried on the derivation: reading the built
        # file would be import-from-derivation.
        toml = file.source.value;
      in
      {
        paletteIsVogix = toml.palette == { dark = "vogix-dark"; light = "vogix-light"; };
        settingsKept = toml.screen.notifications == "on";
        replacesFirstLaunchFile = file.force;
        noPackage = !(lib.any (p: (p.pname or "") == "baud")
          config.home-manager.users.other.home.packages);
        nothingToSay = !(config.home-manager.users.other.xdg.configFile ? "baud/config.toml");
        vogixThemesIt = config.home-manager.users.shelluser.programs.vogix.baud.enable;
        onByDefault = defaulted.programs.vogix.baud.enable
          && defaulted.xdg.configFile."baud/config.toml".source.value.palette.dark == "vogix-dark";
      });

  # The PIN is asked once per power-up of the key: every gpg-agent cache is
  # 400 days, within gpg-agent's 2^31-1 second ceiling.
  gpg-agent-pin-once = evalClauses "gpg-agent-pin-once"
    {
      networking.hostName = "test-gpg-agent-ttl";
      my = {
        hardware.securityKeys.yubico.enable = true;
        users.shelluser = {
          fullName = "Shell User";
          description = "shell";
          email = "shell@example.com";
          # The agent is configured for a user with keys; a placeholder one,
          # never read (this is evaluation only).
          yubikeys = [{
            serial = "1";
            keyId = "AAAAAAAA";
            fingerprint = "AAAA";
            sshKeygrip = "GRIP";
            publicKeyPath = ./module-eval.nix;
            u2fKeyHandle = "HANDLE";
            u2fPublicKey = "PUB";
          }];
        };
      };
    }
    (config:
      let a = config.home-manager.users.shelluser.services.gpg-agent; in
      {
        fourHundredDays = lib.all (t: t == 34560000)
          [ a.defaultCacheTtl a.maxCacheTtl a.defaultCacheTtlSsh a.maxCacheTtlSsh ];
      });

  # residentSerials says which keys live in this machine. Only those are
  # offered over SSH (a stub for a card in another machine makes the agent
  # prompt to insert it), the first becomes gpg's default-key over `primary`,
  # and that is all it changes: sudo trusts every key. Without it, every key is offered and primary
  # is the default, as before.
  security-keys-resident =
    let
      keys = [
        {
          serial = "111";
          keyId = "PRIMARYELSEWHERE";
          primary = true;
          fingerprint = "AAAA";
          sshKeygrip = "GRIPAWAY";
          sshPublicKey = "ssh-ed25519 AWAY";
          publicKeyPath = ./module-eval.nix;
          u2fKeyHandle = "H1";
          u2fPublicKey = "P1";
        }
        {
          serial = "222";
          keyId = "LIVESHERE";
          fingerprint = "BBBB";
          sshKeygrip = "GRIPHERE";
          sshPublicKey = "ssh-ed25519 HERE";
          publicKeyPath = ./module-eval.nix;
          u2fKeyHandle = "H2";
          u2fPublicKey = "P2";
        }
      ];
      host = resident: {
        networking.hostName = "test-resident";
        my = {
          hardware.securityKeys = {
            yubico.enable = true;
            residentSerials = resident;
          };
          security = {
            enable = true;
            sshAgentSudo.enable = true;
          };
          users.shelluser = {
            fullName = "Shell User";
            description = "shell";
            email = "shell@example.com";
            yubikeys = keys;
          };
        };
      };
      evalWith = resident: (lib.nixosSystem {
        inherit specialArgs;
        modules = baseModules ++ [ baseConfig (host resident) ];
      }).config;
      here = evalWith [ "222" ];
      unset = evalWith [ ];
      sshcontrol = c: c.home-manager.users.shelluser.home.file.".gnupg/sshcontrol".text;
      defaultKey = c: c.home-manager.users.shelluser.programs.gpg.settings.default-key;
      sudoKeys = c: c.environment.etc."sudo-ssh-agent-keys.d/shelluser".text;
      ok = {
        offersOnlyResident = lib.hasInfix "GRIPHERE" (sshcontrol here)
          && !(lib.hasInfix "GRIPAWAY" (sshcontrol here));
        defaultIsResident = defaultKey here == "LIVESHERE";
        # Owner: sudo trusts every key, the resident one too.
        sudoTrustsAll = lib.hasInfix "AWAY" (sudoKeys here)
          && lib.hasInfix "HERE" (sudoKeys here);
        unsetOffersAll = lib.hasInfix "GRIPHERE" (sshcontrol unset)
          && lib.hasInfix "GRIPAWAY" (sshcontrol unset);
        unsetDefaultIsPrimary = defaultKey unset == "PRIMARYELSEWHERE";
      };
      failed = builtins.attrNames (lib.filterAttrs (_: v: !v) ok);
    in
    if failed != [ ] then builtins.throw "FAIL: module-eval-security-keys-resident -- did not hold: ${lib.concatStringsSep ", " failed}"
    else
      pkgs.runCommand "module-eval-security-keys-resident" { } ''
        echo "PASS: security-keys-resident"
        touch $out
      '';

  # With a security key on the host, the greeter's auth stack must carry
  # pam_u2f NON-interactively (touch-to-login; SDDM cannot answer the
  # interactive "press ENTER" conversation), ordered AFTER unix so a typed
  # password logs in without waiting out the touch timeout — while the TTY
  # login stack keeps the fleet's interactive prompt.
  login-sddm-u2f-touch = evalAssert "login-sddm-u2f-touch"
    {
      networking.hostName = "test-sddm-u2f";
      my = {
        theming = {
          enable = true;
          vogix.enable = true;
        };
        hardware.securityKeys.yubico.enable = true;
        users.shelluser = {
          fullName = "Shell User";
          description = "shell";
          email = "shell@example.com";
          graphical.enable = true;
        };
      };
    }
    (config:
      let auth = config.security.pam.services.sddm.rules.auth; in
      (auth ? u2f)
      && auth.u2f.settings.interactive == false
      && auth.u2f.settings.cue == true
      && (auth ? unix)
      && auth.unix.order < auth.u2f.order
      && !(auth ? login)
      # The TTY stack is untouched: interactive stays the fleet default.
      && config.security.pam.u2f.settings.interactive == true);

  graphical-shell-none = evalAssert "graphical-shell-none"
    {
      networking.hostName = "test-shell-none";
      my = {
        theming = {
          enable = false;
          vogix.enable = false;
        };
        users.shelluser = {
          fullName = "Shell User";
          description = "shell";
          email = "shell@example.com";
          graphical = {
            enable = true;
            shell = "none";
          };
        };
      };
    }
    (config:
      let hm = config.home-manager.users.shelluser; in
      !(hm.programs.waybar.enable or false)
      && !(hm.systemd.user.services ? vogix-desktop));

  # Radicle forge: the full seed-host shape (node + httpd + CI + mirror).
  # Everything the dossier calls a trap is asserted here, because each one
  # fails silently on a real host: openFirewall would open 8776 on the WAN,
  # preferredSeeds would leak iris/rosa into a private net, a dropped Node
  # filter would let anyone's patch run shell on the seed, and a missing nix
  # in the adapter PATH means every recipe's `nix build` dies at runtime.
  radicle-seed = evalAssert "radicle-seed"
    {
      networking.hostName = "test-radicle";
      my = {
        secrets.enable = true;
        network.tailscale.enable = true;
        dev.remoteBuilders = [{
          hostName = "mac.example.ts.net";
          systems = [ "aarch64-darwin" ];
          publicHostKey = "c3NoLWVkMjU1MTkgQUFBQQo=";
        }];
        infra.radicle = {
          enable = true;
          publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBgFMhajUng+Rjj/sCFXI9PzG8BQjru2n7JgUVF1Kbv5";
          node = {
            externalAddresses = [ "seed.example.ts.net:8776" ];
            defaultSeedingPolicy = "allow";
            connect = [ "z6MkTest@peer.example.ts.net:8776" ];
          };
          seedRepositories = [{ rid = "rad:z2y7KqUhUxZQ7Zhn1UNwmuMDtstTS"; }];
          httpd = {
            enable = true;
            explorer = {
              enable = true;
              scheme = "https";
              seedHostname = "seed.example.ts.net";
            };
          };
          ci = {
            enable = true;
            trustedNids = [ "z6MkTrusted" ];
          };
          mirror = {
            enable = true;
            sourceNid = "z6MkTrusted";
            notifyCommand = "true";
            repos = [{
              rid = "rad:z2y7KqUhUxZQ7Zhn1UNwmuMDtstTS";
              githubRepo = "example/demo";
              releases = { enable = true; systems = [ "x86_64-linux" "aarch64-darwin" ]; };
            }];
          };
        };
      };
    }
    (config:
      let
        settings = config.services.radicle.settings;
        broker = config.services.radicle.ci.broker.settings;
        adapterPath = broker.adapters.native.env.PATH;
        mirrorPath = config.systemd.services.radicle-mirror-example-demo.environment.PATH;
        nodeUnit = config.systemd.services.radicle-node;
      in
      # Node: tailnet-only reachability, no public seeds, static peers.
      config.services.radicle.enable
      && !config.services.radicle.node.openFirewall
      && builtins.elem 8776 config.my.network.tailscale.allowedTCPPorts
      && builtins.elem 8780 config.my.network.tailscale.allowedTCPPorts
      && !(builtins.elem 8776 config.networking.firewall.allowedTCPPorts)
      && settings.preferredSeeds == [ ]
      && settings.node.peers.type == "static"
      && settings.node.connect == [ "z6MkTest@peer.example.ts.net:8776" ]
      && settings.node.externalAddresses == [ "seed.example.ts.net:8776" ]      # The module MAPS "allow" -> { default="allow"; scope="all"; } (rad treats a
      # scope-less allow as followed-only). Assert the whole attrset, not just
      # the half the test config itself set.
      && settings.node.seedingPolicy == { default = "allow"; scope = "all"; }
      && builtins.elem "tailscaled.service" nodeUnit.after
      # Declarative seeding + httpd.
      && config.systemd.services ? radicle-seed-repos
      && config.systemd.services ? radicle-httpd
      # The explorer is a static SPA served by OUR nginx -- never through
      # services.radicle.httpd.nginx, whose non-null branch would rewrite
      # externalAddresses to a public DNS name and switch on ACME.
      && config.services.nginx.enable
      && config.services.radicle.httpd.nginx == null
      # Under https the explorer port is loopback-only and must NOT be
      # opened on the tailnet -- tailscale serve is the only entrance.
      && !(builtins.elem 8781 config.my.network.tailscale.allowedTCPPorts)
      && (builtins.head config.services.nginx.virtualHosts."radicle-explorer".listen).addr == "127.0.0.1"
      && (config.services.nginx.virtualHosts."radicle-explorer".locations."/".tryFiles or "") == "$uri $uri/ /index.html"
      # Single origin: the SPA and its API must share a scheme+host+port, or
      # an https page cannot call the api at all (mixed content).
      && lib.hasInfix "127.0.0.1:8780/api/"
        (config.services.nginx.virtualHosts."radicle-explorer".locations."/api/".proxyPass or "")
      # Raw blobs, which is how the explorer renders any image a README cites.
      # httpd mounts /raw OUTSIDE the API, so it does not appear in the
      # /api/v1 link index -- enumerating that index concludes the endpoint
      # does not exist. Asserted here because the failure is SILENT: without
      # the location the request falls through to the SPA fallback and returns
      # index.html with a 200, so a committed badge renders as a broken image
      # while the file is present and valid and the explorer's URL is correct.
      && lib.hasInfix "127.0.0.1:8780/raw/"
        (config.services.nginx.virtualHosts."radicle-explorer".locations."/raw/".proxyPass or "")
      && config.systemd.services ? radicle-explorer-serve
      # CI: broker on, trigger carries the Node filter, adapter PATH has nix
      # and the build helper (an upstream mkForce on runtimePackages would
      # break the concat and fail HERE, not on a host).
      && config.services.radicle.ci.broker.enable
      && lib.any
        (t: lib.any (f: lib.any (c: c ? Or && lib.any (n: n.Node or null == "z6MkTrusted") c.Or) (f.And or [ ])) t.filters)
        broker.triggers
      && lib.hasInfix "-nix-" adapterPath
      && lib.hasInfix "radicle-ci-build" adapterPath
      # The release path shells out to tar/gzip, and systemd.services.<n>.path
      # REPLACES PATH rather than extending it -- so a missing archiver is
      # invisible until a real tag lands. Guard it here.
      && lib.hasInfix "gnutar" mirrorPath
      && lib.hasInfix "gzip" mirrorPath
      # Mirror: per-repo service/path/timer triple + notify template, token
      # via LoadCredential, and the delegate-namespace watch path.
      && config.systemd.services ? radicle-mirror-example-demo
      && config.systemd.paths ? radicle-mirror-example-demo
      && config.systemd.timers ? radicle-mirror-example-demo
      && config.systemd.services ? "radicle-mirror-notify@"
      && lib.any (lib.hasPrefix "github-token:")
        config.systemd.services.radicle-mirror-example-demo.serviceConfig.LoadCredential
      && config.systemd.paths.radicle-mirror-example-demo.pathConfig.PathModified
      == "/var/lib/radicle/storage/z2y7KqUhUxZQ7Zhn1UNwmuMDtstTS/refs/namespaces/z6MkTrusted/refs/rad/sigrefs"
      # Remote builders: buildMachines renders with ssh-ng and the sops key.
      && (builtins.head config.nix.buildMachines).protocol == "ssh-ng"
      && (builtins.head config.nix.buildMachines).systems == [ "aarch64-darwin" ]
      && config.nix.distributedBuilds
      # Persistence: forge state survives impermanence.
      && builtins.elem "/var/lib/radicle" config.my.system.persistence.features.systemDirectories
      && builtins.elem "/var/lib/radicle-ci" config.my.system.persistence.features.systemDirectories
      && builtins.elem "/var/lib/radicle-mirror" config.my.system.persistence.features.systemDirectories);

  # CI with nothing served over nginx: no explorer, no reports. Nothing enables
  # nginx, so nothing may declare its account either; a stray
  # `users.users.nginx` attribute is an account with no group, which the users
  # module refuses.
  radicle-ci-without-reports = evalClauses "radicle-ci-without-reports"
    {
      networking.hostName = "test-radicle-ci";
      my = {
        secrets.enable = true;
        network.tailscale.enable = true;
        infra.radicle = {
          enable = true;
          publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBgFMhajUng+Rjj/sCFXI9PzG8BQjru2n7JgUVF1Kbv5";
          node.defaultSeedingPolicy = "allow";
          httpd.enable = true;
          ci = {
            enable = true;
            trustedNids = [ "z6MkTrusted" ];
          };
        };
      };
      # Every assertion is read, so the key is a fixed path rather than a
      # sops secret with no file behind it.
      services.radicle.privateKey = lib.mkForce "/run/radicle-node.key";
      sops.secrets = lib.mkForce { };
    }
    (config: {
      nginx-off = !config.services.nginx.enable;
      no-nginx-account = !(config.users.users ? nginx);
      assertions-hold = lib.all (a: a.assertion) config.assertions;
    });

  # An RKE2 server's airgap archives and Cilium's cgroup root. RKE2 finds its
  # runtime image only among the files directly in agent/images, so each archive
  # is linked there and none goes through services.rke2.images, which links one
  # level down. Cilium runs on the host's cgroup2 mount rather than mounting its
  # own, which shutdown could not unmount.
  rke2-airgap-layout = evalClauses "rke2-airgap-layout"
    {
      networking.hostName = "test-rke2";
      my = {
        secrets.enable = true;
        network.tailscale.enable = true;
        infra.rke2 = {
          enable = true;
          role = "server";
          nodeName = "test-rke2";
          nodeIP = "100.64.0.1";
          tokenFile = "/run/rke2-token";
        };
      };
    }
    (config:
      let
        imageDir = "/var/lib/rancher/rke2/agent/images/";
        links = lib.filterAttrs (path: _: lib.hasPrefix imageDir path)
          (config.systemd.tmpfiles.settings."10-rke2-airgap-images" or { });
        cilium = builtins.fromJSON config.services.rke2.manifests.rke2-cilium-config.content.spec.valuesContent;
      in
      {
        images-not-nested = config.services.rke2.images == [ ];
        archives-linked-at-top = links != { }
          && lib.all (path: !(lib.hasInfix "/" (lib.removePrefix imageDir path))) (builtins.attrNames links);
        runtime-archive-linked = lib.any (path: lib.hasInfix "images-core" path) (builtins.attrNames links);
        # Unset keys read as the chart's defaults: autoMount on, /run/cilium/cgroupv2.
        cilium-no-own-cgroup-mount = !(cilium.cgroup.autoMount.enabled or true)
          && (cilium.cgroup.hostRoot or "/run/cilium/cgroupv2") == "/sys/fs/cgroup";
      });

  # Workstation shape: node only, block policy, no CI/mirror/httpd -- and the
  # per-user app: rad CLI in home packages plus the outbound-only user node
  # with a pinned private-net config.
  radicle-workstation = evalAssert "radicle-workstation"
    {
      networking.hostName = "test-radicle-ws";
      my = {
        secrets.enable = true;
        network.tailscale.enable = true;
        infra.radicle = {
          enable = true;
          publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBgFMhajUng+Rjj/sCFXI9PzG8BQjru2n7JgUVF1Kbv5";
          node.connect = [ "z6MkSeed@seed.example.ts.net:8776" ];
        };
        users.raduser = {
          fullName = "Rad User";
          description = "rad";
          email = "rad@example.com";
          apps.dev.tools.radicle = {
            enable = true;
            node = {
              enable = true;
              connect = [ "z6MkSeed@seed.example.ts.net:8776" ];
            };
          };
        };
      };
    }
    (config:
      let hm = config.home-manager.users.raduser; in
      config.services.radicle.enable
      && config.services.radicle.settings.node.seedingPolicy.default == "block"
      && !config.services.radicle.ci.broker.enable
      && !(config.systemd.services ? radicle-httpd)
      && builtins.any (p: (p.pname or "") == "radicle-node") hm.home.packages
      && hm.systemd.user.services ? radicle-node
      && lib.hasInfix "--config" (toString hm.systemd.user.services.radicle-node.Service.ExecStart)
      && hm.systemd.user.services ? radicle-config-pin);

  # --- Tailnet reachability: a port belongs to the feature that needs it -----
  #
  # sshd's port on tailscale0 is contributed by my/network/openssh, gated on
  # sshd actually running -- NOT hard-coded by my/network/tailscale, which used
  # to prepend a literal 22 and so advertised SSH on roles that switch sshd off.
  #
  # The gate also has to stay on `services.openssh.enable` rather than on
  # anything under `my.network`: that whole namespace is one submodule option,
  # so a contribution to `my.network.tailscale.allowedTCPPorts` from the openssh
  # module closes an evaluation loop through its own `mkIf` condition. These two
  # checks fail with infinite recursion if that shape ever comes back.
  tailnet-ssh-port-with-sshd = evalAssert "tailnet-ssh-port-with-sshd"
    {
      networking.hostName = "test-tailnet-ssh-on";
      my.network.tailscale = {
        enable = true;
        allowedTCPPorts = [ 9999 ];
      };
    }
    (config:
      config.services.openssh.enable
      && builtins.elem 22 config.networking.firewall.interfaces.tailscale0.allowedTCPPorts
      && builtins.elem 9999 config.networking.firewall.interfaces.tailscale0.allowedTCPPorts);

  tailnet-ssh-port-without-sshd = evalAssert "tailnet-ssh-port-without-sshd"
    {
      networking.hostName = "test-tailnet-ssh-off";
      my.network.tailscale = {
        enable = true;
        allowedTCPPorts = [ 9999 ];
      };
      # What platforms/oci-variant.nix does to every role.
      services.openssh.enable = lib.mkForce false;
    }
    (config:
      !config.services.openssh.enable
      && config.networking.firewall.interfaces.tailscale0.allowedTCPPorts == [ 9999 ]);

  # A tailnet host resolves through systemd-resolved: NetworkManager hands it
  # each link's DNS, and tailscaled scopes MagicDNS to tailscale0 instead of
  # owning /etc/resolv.conf. The rendered resolved.conf keeps LLMNR and mDNS
  # off and FallbackDNS empty.
  tailnet-dns-resolved = evalAssert "tailnet-dns-resolved"
    {
      networking.hostName = "test-tailnet-dns";
      my.network.tailscale.enable = true;
    }
    (config:
      let
        conf = lib.splitString "\n" config.environment.etc."systemd/resolved.conf".text;
      in
      config.services.resolved.enable
      && config.networking.networkmanager.dns == "systemd-resolved"
      && builtins.elem "LLMNR=false" conf
      && builtins.elem "MulticastDNS=false" conf
      && builtins.elem "FallbackDNS=" conf);

  # A tailnet node in a container keeps the resolv.conf its runtime writes.
  tailnet-dns-container = evalAssert "tailnet-dns-container"
    {
      networking.hostName = "test-tailnet-dns-container";
      boot.isContainer = true;
      my.network.tailscale.enable = true;
    }
    (config:
      !config.services.resolved.enable
      && config.networking.useHostResolvConf);

  # The nixpkgs module's checkConfig runs `rad config` against the generated
  # config.json at BUILD time. The toplevel-forcing suites can't enable
  # radicle (sops assertions, no fixture precedent), so build the configFile
  # derivation directly -- this is the only place the settings JSON meets a
  # real `rad` binary before a host does.
  radicle-config-valid =
    (lib.nixosSystem {
      inherit specialArgs;
      modules = baseModules ++ [
        baseConfig
        {
          networking.hostName = "test-radicle-cfg";
          my = {
            secrets.enable = true;
            network.tailscale.enable = true;
            infra.radicle = {
              enable = true;
              publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBgFMhajUng+Rjj/sCFXI9PzG8BQjru2n7JgUVF1Kbv5";
              node = {
                connect = [ "z6MkuEBniT9BRGVjKUUV2Yi8dcEHzbDAn1fD5meaZ33bNMJV@seed.example.ts.net:8776" ];
                externalAddresses = [ "seed.example.ts.net:8776" ];
                defaultSeedingPolicy = "allow";
              };
            };
          };
        }
      ];
    }).config.services.radicle.configFile;

  # --- Roles: my.infra.radicle inside `mkSystem { platform = "oci"; }` ------
  #
  # The point of the oci emitter is that the domain is reused UNCHANGED, so
  # what these assert is not "the image exists" but "the same units, the same
  # credential delivery and the same web view come out of a role as out of a
  # host" -- plus the two things only a container can get wrong: a bootloader
  # it cannot have, and accounts it must not have.
  #
  # `system.build.image.drvPath` is forced, which pulls the whole toplevel and
  # therefore every assertion in the system (ci.trustedNids' among them). These
  # are the only checks here that go that deep, and they can: a role has no
  # users, so none of the import-from-derivation vogix does is on the path.
  oci-radicle-builder = systemAssert "oci-radicle-builder"
    (self.lib.mkSystem {
      inherit system;
      hostname = "radicle-x64-builder";
      my = [{
        network.tailscale.enable = true;
        infra.radicle = {
          enable = true;
          builder.enable = true;
          publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBgFMhajUng+Rjj/sCFXI9PzG8BQjru2n7JgUVF1Kbv5";
          privateKeyFile = "/var/lib/radicle-identity/node-key";
          ci.trustedNids = [ "z6MkuEBniT9BRGVjKUUV2Yi8dcEHzbDAn1fD5meaZ33bNMJV" ];
          node.connect = [ "z6MkSeed@radicle-seed.example.ts.net:8776" ];
        };
      }];
    })
    (config:
      # THE MACHINE IS NOT A CONTAINER; ITS IMAGE IS. boot.isContainer and the nix
      # DB loader come from the docker-container profile, which lives only inside
      # the variant -- so asserting them of the MACHINE would be asserting the old
      # model, where a role was constructed as a container rather than expressed
      # as one. `img` is that machine seen as its image, and the split is the
      # point: the domain is true of the machine, being a container is true only
      # of the image.
      let img = config.virtualisation.ociVariant; in
      img.boot.isContainer
      && img.systemd.services ? register-nix-paths
      && !img.boot.loader.systemd-boot.enable
      && !img.boot.lanzaboote.enable

      # The domain, unchanged: node + broker + adapter, with the key still
      # delivered by LoadCredential -- from a file rather than from sops.
      && config.services.radicle.enable
      && config.services.radicle.ci.broker.enable
      && config.systemd.services ? radicle-node
      && config.services.radicle.settings.node.seedingPolicy.default == "block"

      # A builder serves nothing. httpd and the explorer belong to a seed.
      && !(config.systemd.services ? radicle-httpd)

      # And it is not logged into either: sshd is off, so nothing may put 22 on
      # the tailnet. Exactly two ports are reachable and both are named here, so
      # a third one appearing has to be argued for rather than merely noticed:
      # the node's P2P port, and the CI reports the builder serves because it is
      # the only machine they exist on.
      # ...of the IMAGE. The machine is an ordinary Linux system and has sshd like
      # any other; the variant is what forces it off, and with it the port. That
      # is the distinction this whole change is about: a machine does not stop
      # being a machine because someone takes a container image of it.
      && !img.services.openssh.enable
      && img.networking.firewall.interfaces.tailscale0.allowedTCPPorts == [ 8776 8782 ]
      && config.services.nginx.enable
      && !config.services.radicle.httpd.enable

      # No accounts, which is what keeps home-manager and a workstation's
      # closure out of the image.
      && config.my.users == { }
      && builtins.attrNames config.home-manager.users == [ ]

      # The identity contract. A role declares NO sops secrets at all, and the
      # assertion is on the whole set rather than on one absent name: sops-nix
      # runs sops-install-secrets whenever ANY secret is declared, and that tool
      # mounts a ramfs, which needs a CAP_SYS_ADMIN this role must not have. One
      # stray secret from any module would put it back in the activation path,
      # and the failure would surface as `cannot mount: operation not permitted`
      # from inside a nested boot.
      && config.sops.secrets == { }
      && !config.my.secrets.enable

      # The key is a RUNTIME path under the directory the host bind-mounts, so
      # one image serves every builder and the container carries the identity.
      # Checked for the store prefix too: a store path here would mean the key
      # was baked into the image, which is the one thing this design forbids.
      && config.services.radicle.privateKey == "/var/lib/radicle-identity/node-key"
      && !(lib.hasPrefix builtins.storeDir config.services.radicle.privateKey)

      && config.system.build.image.imageName == "radicle-x64-builder");

  oci-radicle-seed = systemAssert "oci-radicle-seed"
    (self.lib.mkSystem {
      inherit system;
      hostname = "radicle-seed";
      my = [{
        network.tailscale.enable = true;
        # A SEED HAS NO `connect`, so nothing derives a liveness peer for it and
        # the assertion refuses to evaluate until one is named. That is the
        # intended shape: a role that cannot say what it must be able to reach
        # is not in a position to claim it is alive.
        network.tailscale.liveness.peers = [ "yoga" ];
        infra.radicle = {
          enable = true;
          seed.enable = true;
          publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBgFMhajUng+Rjj/sCFXI9PzG8BQjru2n7JgUVF1Kbv5";
          privateKeyFile = "/var/lib/radicle-identity/node-key";
          node.externalAddresses = [ "radicle-seed.example.ts.net:8776" ];
          httpd.explorer.seedHostname = "radicle-seed.example.ts.net";
        };
      }];
    })
    (config:
      config.virtualisation.ociVariant.boot.isContainer
      && config.services.radicle.enable
      # A seed holds every peer's refs; that is what makes seeds plural and a
      # second one able to pull the repositories across.
      && config.services.radicle.settings.node.seedingPolicy.default == "allow"
      && config.systemd.services ? radicle-httpd

      # Its OWN nginx, inside the role -- the explorer no longer has to cross a
      # container boundary to be served.
      && config.services.nginx.enable
      && config.services.nginx.virtualHosts ? "radicle-explorer"

      # A seed runs no CI: the broker is a builder's job.
      && !config.services.radicle.ci.broker.enable

      && config.my.users == { }
      && config.system.build.image.imageName == "radicle-seed");

  # A caller-supplied `name` is the node name VERBATIM, not a suffix.
  #
  # The check above cannot see this: it takes the default, so a role that
  # prefixed "radicle-" onto the argument would produce "radicle-seed" either
  # way and pass. The role did exactly that, and the deployment that named its
  # seed `radicle-yoga-seed` -- the naming ./builder.nix argues for, since a
  # tailnet name must be unique fleet-wide -- silently became
  # `radicle-radicle-yoga-seed`.
  #
  # Nothing downstream complains. The image builds, the container boots, and
  # the breakage is that tailscaled registers under the doubled name while
  # `externalAddresses` and `seedHostname` still carry the intended one: the
  # seed advertises an address that does not resolve and its explorer fetches
  # from a host that is not there. Both read as tailnet faults.
  oci-radicle-seed-named = systemAssert "oci-radicle-seed-named"
    (self.lib.mkSystem {
      inherit system;
      hostname = "radicle-yoga-seed";
      my = [{
        network.tailscale.enable = true;
        # Named for the same reason as the fixture above: a seed dials nobody.
        network.tailscale.liveness.peers = [ "yoga" ];
        infra.radicle = {
          enable = true;
          seed.enable = true;
          publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBgFMhajUng+Rjj/sCFXI9PzG8BQjru2n7JgUVF1Kbv5";
          privateKeyFile = "/var/lib/radicle-identity/node-key";
          node.externalAddresses = [ "radicle-yoga-seed.example.ts.net:8776" ];
          httpd.explorer.seedHostname = "radicle-yoga-seed.example.ts.net";
        };
      }];
    })
    (config:
      config.system.build.image.imageName == "radicle-yoga-seed"
      # The hostname is what tailscaled registers as, so it is the half that
      # has to agree with the advertised address -- asserting only the image
      # name would let the two drift apart again.
      && config.networking.hostName == "radicle-yoga-seed");

  # --- my.hardware.display ----------------------------------------------------

  # (b) With nothing declared, the one rule is the wildcard, and it is the
  # built-in defaults: HDR on, highest resolution then refresh.
  display-wildcard-defaults = evalClauses "display-wildcard-defaults" (displayHost { })
    (config: {
      wildcard-only = monitorRules config == [ displayWildcard ];
      no-workspace-rules = !((hyprSettings config) ? workspace_rule);
      # Auto-HDR is off: with monitors always in HDR, Hyprland 0.57 would
      # otherwise send SDR metadata for any fullscreen sRGB-tagged surface
      # (Mesa WSI tags Vulkan swapchains) while still rendering PQ.
      no-auto-hdr = ((hyprSettings config).config.render.cm_auto_hdr or null) == 0;
      # ...and it must reach Hyprland: top-level settings keys render as
      # hl.<key>(...) calls, and only hl.config sets options (there is no
      # hl.render), so check the rendered file, not just the attrset.
      no-auto-hdr-rendered =
        let text = config.home-manager.users.hypruser.xdg.configFile."hypr/hyprland.lua".text; in
        !(lib.hasInfix "hl.render(" text) && lib.hasInfix ''["cm_auto_hdr"] = 0'' text;
    });

  # (a) A catalogued model: its facts (make, model, 10-bit HDR, content-gated VRR)
  # become one rule beside the wildcard, and nothing equal to Hyprland's own
  # defaults is written. The mode stays "highres" so the link decides (4K@240
  # on DP 1.4 + DSC, 4K@60 on HDMI TMDS); the native mode is geometry only.
  display-aw3225qf = evalClauses "display-aw3225qf"
    (displayHost { monitors.dell.aw3225qf.main = { }; })
    (config:
      let text = config.home-manager.users.hypruser.xdg.configFile."hypr/hyprland.lua".text; in {
        clean = displayClean config;
        rules = monitorRules config == [
          displayWildcard
          (displayWildcard // { output = aw; })
        ];
        rendered = lib.hasInfix ''["output"] = "desc:Dell Inc. AW3225QF"'' text
          && lib.hasInfix ''["mode"] = "highres"'' text;
      });

  # (c) rightOf with scale 1.5 and a 90° turn: 3840x2160/1.5 is 2560x1440, the
  # turned 2560x1440 panel is 1440x2560, centred it starts 560 higher, and
  # normalising moves the first one down by that much instead.
  display-layout-placement = evalClauses "display-layout-placement"
    (displayHost {
      monitors = {
        dell.aw3225qf.main = { };
        generic.side = { output = "DP-2"; mode = { width = 2560; height = 1440; refresh = 60; }; };
      };
      layout = {
        main.scale = 1.5;
        side = {
          position = { rightOf = "main"; align = "center"; };
          transform.rotation = 90;
        };
      };
    })
    (config: {
      clean = displayClean config;
      main = (ruleFor aw config) == displayWildcard // { output = aw; position = "0x560"; scale = "1.5"; };
      side = (ruleFor "DP-2" config) == displayWildcard // { output = "DP-2"; mode = "2560x1440@60"; position = "2560x0"; transform = 1; };
    });

  # (d) Workspaces become persistent workspace rules with the first as the
  # default; a mirror names the mirrored monitor's selector; a serial narrows
  # the selector; a disabled monitor is just `disabled`.
  display-workspaces-mirror = evalClauses "display-workspaces-mirror"
    (displayHost {
      monitors = {
        dell.aw3225qf.main.serial = "SN1";
        generic = {
          laptop.output = "eDP-1";
          spare.output = "HDMI-A-2";
        };
      };
      layout = {
        main.workspaces = [ 1 2 ];
        laptop.mirror = "main";
        spare.enable = false;
      };
    })
    (config: {
      clean = displayClean config;
      workspaces = (hyprSettings config).workspace_rule == [
        { workspace = "1"; monitor = "${aw} SN1"; default = true; persistent = true; }
        { workspace = "2"; monitor = "${aw} SN1"; persistent = true; }
      ];
      serial = ruleFor "${aw} SN1" config != null;
      mirror = (ruleFor "eDP-1" config).mirror == "${aw} SN1";
      disabled = ruleFor "HDMI-A-2" config == { output = "HDMI-A-2"; disabled = true; };
    });

  # The SDR shape a host uses for a mirrored external at 1440p: nothing HDR is
  # written for it, while the laptop keeps the defaults.
  display-sdr-instance = evalClauses "display-sdr-instance"
    (displayHost {
      monitors = {
        dell.aw3225qf.external = {
          output = "HDMI-A-1";
          mode = { width = 2560; height = 1440; refresh = 59.95; };
          bitDepth = 8;
          hdr.enable = false;
        };
        generic.laptop = { output = "eDP-1"; mode = { width = 2560; height = 1600; refresh = 240; }; };
      };
      layout = {
        external.position = { x = 0; y = 0; };
        laptop.mirror = "external";
      };
    })
    (config: {
      clean = displayClean config;
      external = ruleFor "HDMI-A-1" config == { output = "HDMI-A-1"; mode = "2560x1440@59.95"; position = "0x0"; scale = "1"; vrr = 3; };
      laptop = ruleFor "eDP-1" config == displayWildcard // { output = "eDP-1"; mode = "2560x1600@240"; mirror = "HDMI-A-1"; };
    });

  # (e) The AW3225QF's HDR modes carry its EDID luminance; "edid" (the default,
  # covered by display-aw3225qf) writes none.
  display-hdr-mode = evalClauses "display-hdr-mode"
    (displayHost {
      monitors.dell.aw3225qf = {
        dp = { output = "DP-1"; hdrMode = "peak1000"; };
        hdmi = { output = "HDMI-A-1"; hdrMode = "trueBlack400"; };
      };
    })
    (config: {
      clean = displayClean config;
      peak1000 = (ruleFor "DP-1" config).max_luminance == 993 && (ruleFor "DP-1" config).max_avg_luminance == 277;
      trueBlack400 = (ruleFor "HDMI-A-1" config).max_luminance == 427 && (ruleFor "HDMI-A-1" config).max_avg_luminance == 265;
    });

  # (f) HDMI FRL: the feature-mask bit on a kernel that has it off by default,
  # nothing from 7.4 on (where it is on), nothing when not asked, and only on
  # an AMD GPU.
  # The Corsair HX1200i Series 2025 PSU (USB 1b1c:1c27): sensors only. The
  # in-kernel corsair-psu hwmon driver reports rails, power, fan and temps;
  # lm_sensors shows them. No fan or OCP control is sent.
  # Logi Bolt receiver (046d:c548): udev rules + ltunify, and Solaar with its
  # per-user tray service (pairing, battery, button settings).
  peripheral-logitech-bolt = evalAssert "peripheral-logitech-bolt"
    {
      networking.hostName = "test-bolt";
      my.hardware.peripherals.logitech.bolt.enable = true;
    }
    (config: config.hardware.logitech.wireless.enable
      && config.programs.solaar.enable
      && config.programs.solaar.userService.enable
      && lib.hasInfix "hide" (toString config.systemd.user.services.solaar.serviceConfig.ExecStart));

  # tray = false keeps Solaar installed but does not start it with the session.
  peripheral-logitech-bolt-no-tray = evalAssert "peripheral-logitech-bolt-no-tray"
    {
      networking.hostName = "test-bolt";
      my.hardware.peripherals.logitech.bolt = { enable = true; tray = false; };
    }
    (config: config.programs.solaar.enable && !(config.systemd.user.services ? solaar));

  # VRR defaults to "content" (Hyprland vrr 3): only a fullscreen window that
  # declares game or video content gets VRR. Plain fullscreen VRR (2) made a
  # QD-OLED pulse with an SDR app presenting 24-60 fps on a 240 Hz panel
  # (telly on ads-dev1: VRR_ENABLED toggling, refresh tracking frame pacing).
  # "fullscreen" stays available for panels without OLED VRR flicker.
  display-vrr-fullscreen-explicit = evalClauses "display-vrr-fullscreen-explicit"
    (displayHost { monitors.dell.aw3225qf.main.vrr = "fullscreen"; })
    (config: {
      clean = displayClean config;
      vrr2 = (ruleFor aw config).vrr == 2;
    });

  # Elgato Game Capture 4K X: uaccess, so vendor-control tools
  # (elgato4k-linux: HDR tone mapping, EDID mode) run without sudo, under
  # each product ID the card enumerates as (it changes with USB speed mode).
  # Before 73-seat-late.rules, which turns the tag into an ACL.
  # The 4K X sitting in an HDMI chain does not report ELD, so the host forces
  # the downstream monitor's EDID onto that connector and keeps HDMI audio up
  # regardless. Declared on the card (it is the card's fault), not the board:
  # these five parameters and the EDID firmware are exactly what the X870E
  # profile carried for yoga.
  peripheral-elgato-4k-x-passthrough =
    let
      eval = lib.nixosSystem {
        inherit specialArgs;
        modules = baseModules ++ [
          baseConfig
          {
            networking.hostName = "test-4kx";
            my.hardware.peripherals.elgato.game-capture-4k-x = { enable = true; passthrough.output = "HDMI-A-1"; };
          }
        ];
      };
      p = eval.config.boot.kernelParams;
      # hardware.firmware merges into one derivation, so look at the
      # definitions: the EDID must be among the firmware this module adds.
      firmwareHasEdid = builtins.any
        (d: builtins.any (f: builtins.pathExists "${f}/lib/firmware/edid/hdmi-audio.bin") (lib.toList d))
        eval.options.hardware.firmware.definitions;
      ok = lib.all (x: builtins.elem x p) [
        "amdgpu.audio=1"
        "snd_hda_codec_hdmi.enable_all_pins=1"
        "snd_hda_codec_hdmi.static_hdmi_pcm=1"
        "drm.edid_firmware=HDMI-A-1:edid/hdmi-audio.bin"
        "video=HDMI-A-1:e"
      ] && firmwareHasEdid;
    in
    if !ok then builtins.throw "FAIL: module-eval-peripheral-elgato-4k-x-passthrough -- params or EDID firmware missing"
    else pkgs.runCommand "module-eval-peripheral-elgato-4k-x-passthrough" { } "echo PASS; touch $out";

  # The board alone no longer forces anything onto HDMI-A-1.
  x870e-board-has-no-elgato-workaround = evalAssert "x870e-board-has-no-elgato-workaround"
    {
      networking.hostName = "test-x870e";
      my.hardware.motherboards.gigabyte.x870e-aorus-elite-wifi7.enable = true;
    }
    (config: !(lib.any (x: lib.hasPrefix "drm.edid_firmware" x || lib.hasPrefix "snd_hda_codec_hdmi" x) config.boot.kernelParams));

  peripheral-elgato-4k-x = evalAssert "peripheral-elgato-4k-x"
    {
      networking.hostName = "test-4kx";
      my.hardware.peripherals.elgato.game-capture-4k-x.enable = true;
    }
    (config:
      let
        file = "lib/udev/rules.d/70-elgato-4k-x.rules";
        rules = lib.concatMapStrings (p: builtins.readFile "${p}/${file}")
          (builtins.filter (p: builtins.pathExists "${p}/${file}") config.services.udev.packages);
        covers = id: builtins.match ".*0fd9[^\n]*${id}[^\n]*uaccess.*" rules != null;
      in
      covers "009b" && covers "009c" && covers "009d");

  # Stock uvcvideo refuses the card's settings mailbox (XU 4, selector 1),
  # whose length changes per command, with ENOBUFS. The card ships a patched
  # uvcvideo built out of tree for the running kernel, so vendor tools talk
  # through /dev/video0 instead of detaching the driver.
  peripheral-elgato-4k-x-uvcvideo = evalAssert "peripheral-elgato-4k-x-uvcvideo"
    {
      networking.hostName = "test-4kx";
      my.hardware.peripherals.elgato.game-capture-4k-x.enable = true;
    }
    (config: builtins.any
      (p: (p.pname or "") == "uvcvideo-elgato-4k-x"
        && p.version == config.boot.kernelPackages.kernel.version
        && builtins.any (x: baseNameOf x == "uvcvideo-variable-xu.patch") (p.patches or [ ]))
      config.boot.extraModulePackages);

  # --- my.virtualisation ----------------------------------------------------

  # Engines are independent: podman and docker side by side. `docker` the
  # command then belongs to docker, so podman's dockerCompat stays off (nixpkgs
  # asserts the two cannot both claim it), and both stay rootless with no
  # container group handed out.
  containers-both-engines = evalClauses "containers-both-engines"
    {
      networking.hostName = "test-containers-both";
      my.virtualisation.containers.docker.enable = true;
      my.users.devuser = {
        fullName = "Dev User";
        description = "dev user";
        email = "dev@example.com";
        dev.enable = true;
      };
    }
    (config: {
      podman = config.virtualisation.podman.enable;
      docker = config.virtualisation.docker.enable && config.virtualisation.docker.rootless.enable;
      dockerCommandIsDocker = !config.virtualisation.podman.dockerCompat;
      noContainerGroups = !(lib.any
        (u: lib.elem "docker" (u.extraGroups or [ ]) || lib.elem "podman" (u.extraGroups or [ ]))
        (lib.attrValues config.users.users));
      assertionsHold = !(lib.any (a: !a.assertion) config.assertions);
      bothPersisted = lib.elem "/var/lib/docker" config.my.system.persistence.features.systemDirectories
        && lib.elem ".local/share/containers" config.my.system.persistence.features.userDirectories;
    });

  # Full VMs (a Windows guest for vendor tools that exist nowhere else):
  # libvirtd with an emulated TPM for Windows 11, virt-manager, the named
  # users in the root-equivalent libvirtd group and nobody else, and the
  # disks and definitions on /persist rather than a tmpfs root -- declared
  # through the persistence features like every other module.
  virtualisation-libvirt = evalClauses "virtualisation-libvirt"
    {
      networking.hostName = "test-libvirt";
      my = {
        virtualisation.vms.libvirt = { enable = true; users = [ "vmuser" ]; };
        users.vmuser = { fullName = "VM User"; description = "vm"; email = "vm@example.com"; };
        users.other = { fullName = "Other"; description = "other"; email = "other@example.com"; };
      };
    }
    (config: {
      libvirtd = config.virtualisation.libvirtd.enable;
      tpm = config.virtualisation.libvirtd.qemu.swtpm.enable;
      virtManager = config.programs.virt-manager.enable;
      userInGroup = builtins.elem "libvirtd" config.users.users.vmuser.extraGroups;
      othersNot = !(builtins.elem "libvirtd" config.users.users.other.extraGroups);
      persisted = builtins.elem "/var/lib/libvirt" config.my.system.persistence.features.systemDirectories;
    });

  virtualisation-libvirt-off = evalAssert "virtualisation-libvirt-off"
    { networking.hostName = "test-libvirt-off"; }
    (config: !config.virtualisation.libvirtd.enable);

  # Incus: system containers and VMs. nixpkgs refuses it on iptables, so it
  # turns nftables on; the bridge is trusted so guests get DHCP/DNS; the UI
  # listens on localhost unless told otherwise; incus-admin is root-equivalent
  # and gets only the named users.
  virtualisation-incus = evalClauses "virtualisation-incus"
    {
      networking.hostName = "test-incus";
      my = {
        virtualisation.incus = { enable = true; users = [ "vmuser" ]; storage = "btrfs"; ui.enable = true; };
        users.vmuser = { fullName = "VM User"; description = "vm"; email = "vm@example.com"; };
        users.other = { fullName = "Other"; description = "other"; email = "other@example.com"; };
      };
    }
    (config:
      let
        p = config.virtualisation.incus.preseed;
        pool = lib.findFirst (s: s.name == "default") null p.storage_pools;
        bridge = lib.findFirst (n: n.name == "incusbr0") null p.networks;
        profile = lib.findFirst (x: x.name == "default") null p.profiles;
      in
      {
        incus = config.virtualisation.incus.enable;
        ui = config.virtualisation.incus.ui.enable;
        nftables = config.networking.nftables.enable;
        userInGroup = builtins.elem "incus-admin" config.users.users.vmuser.extraGroups;
        othersNot = !(builtins.elem "incus-admin" config.users.users.other.extraGroups);
        poolDriver = pool != null && pool.driver == "btrfs";
        bridgeNat = bridge != null && bridge.config."ipv4.nat" == "true";
        profileWired = profile != null && profile.devices.root.pool == "default"
          && profile.devices.eth0.network == "incusbr0";
        uiOnLocalhost = p.config."core.https_address" == "127.0.0.1:8443";
        bridgeTrusted = builtins.elem "incusbr0" config.networking.firewall.trustedInterfaces;
        persisted = builtins.elem "/var/lib/incus" config.my.system.persistence.features.systemDirectories;
      });

  virtualisation-incus-off = evalAssert "virtualisation-incus-off"
    { networking.hostName = "test-incus-off"; }
    (config: !config.virtualisation.incus.enable && !config.networking.nftables.enable);

  # RKE2's rpfilter exemption is iptables-only; Incus forces nftables. Until RKE2
  # has an nftables branch the two are refused together rather than leaving
  # Cilium's interfaces silently dropped by reverse-path filtering.
  virtualisation-incus-refuses-rke2 = evalAssert "virtualisation-incus-refuses-rke2"
    {
      networking.hostName = "test-incus-rke2";
      my.virtualisation.incus.enable = true;
      my.infra.rke2.enable = true;
    }
    (config: lib.any (a: !a.assertion && lib.hasInfix "Incus" a.message && lib.hasInfix "RKE2" a.message) config.assertions);

  # A declared quickemu machine: Windows from a local ISO, VirtIO drivers and an
  # unattended-setup disc from the store, the owner's ~/VMs persisted, the USB
  # device handed to the owner, and kvm told to ignore the MSRs Windows probes.
  vm-quickemu-windows = evalClauses "vm-quickemu-windows"
    {
      networking.hostName = "test-vm-windows";
      fileSystems."/persist" = {
        device = "/dev/disk/by-label/persist";
        fsType = "ext4";
        neededForBoot = true;
      };
      my = {
        storage.impermanence.enable = true;
        users.vmuser = { fullName = "VM User"; description = "vm"; email = "vm@example.com"; };
        virtualisation.vms.machines.w = {
          owner = "vmuser";
          os = "windows";
          install.iso.sha256 = "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef";
          cpus = 4;
          memory = "8G";
          disk.size = "64G";
          usb = [ "413c:1234" ];
        };
      };
    }
    (config:
      let
        hm = config.home-manager.users.vmuser;
        conf = hm.home.file."VMs/w.conf".text;
        pkgNames = map (p: p.pname or p.name or "") hm.home.packages;
        # Read from the derivations' `text` attributes (writeTextFile and
        # writeShellApplication both carry one), never from built outputs:
        # import-from-derivation here builds every udev package at eval time,
        # and on CI that ended in a stack overflow.
        rules = lib.concatMapStrings (p: p.text or "") config.services.udev.packages;
        userDirs = map (d: d.directory or d) config.environment.persistence."/persist".users.vmuser.directories;
      in
      {
        guestOs = lib.hasInfix ''guest_os="windows"'' conf;
        resources = lib.hasInfix ''cpu_cores="4"'' conf && lib.hasInfix ''ram="8G"'' conf
          && lib.hasInfix ''disk_size="64G"'' conf;
        firmware = lib.hasInfix ''boot="efi"'' conf && lib.hasInfix ''tpm="on"'' conf
          && lib.hasInfix ''secureboot="off"'' conf;
        iso = lib.hasInfix ''iso="/home/vmuser/VMs/w/install.iso"'' conf;
        launcherPinsHash = lib.any (p: (p.name or "") == "vm-w" && lib.hasInfix "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef" (p.text or "")) hm.home.packages;
        virtio = lib.hasInfix "fixed_iso=" conf && lib.hasInfix "virtio-win" conf;
        disk = lib.hasInfix ''disk_img="/home/vmuser/VMs/w/disk.qcow2"'' conf;
        usbInConf = lib.hasInfix ''usb_devices=("413c:1234")'' conf;
        unattended = hm.home.file ? "VMs/w/unattended.iso";
        packages = lib.elem "quickemu" pkgNames && lib.elem "vm-w" pkgNames;
        # The host-only QEMU has no smbd; nixpkgs' quickemu always passes
        # `smb=` regardless, and QEMU then refuses to start the VM.
        noSmbShare = lib.any
          (p: (p.pname or "") == "quickemu"
            && lib.hasInfix "'if false'" (builtins.unsafeDiscardStringContext (p.postPatch or "")))
          hm.home.packages;
        usbOwned = lib.hasInfix ''ATTRS{idVendor}=="413c", ATTRS{idProduct}=="1234", OWNER="vmuser"'' rules;
        vmsPersisted = lib.elem "VMs" userDirs;
        ignoreMsrs = lib.hasInfix "ignore_msrs=1" config.boot.extraModprobeConfig;
      });

  # The main OS carries no build toolchains or dev libraries: compilers,
  # debuggers, toolchain-bound language servers and source converters come
  # per project from devenv. Each name below dragged a C/C++ toolchain or
  # gigabytes of dev closure into every host that enabled its module.
  lean-no-dev-tools = evalClauses "lean-no-dev-tools"
    {
      networking.hostName = "test-lean";
      my = {
        system.enable = true;
        hardware = { gpu = "amd"; audio.enable = true; };
        ai = { enable = true; ollama.enable = true; };
        virtualisation.containers = { podman.enable = true; docker.enable = true; };
        users.leanuser = {
          fullName = "Lean User";
          description = "lean";
          email = "lean@example.com";
          apps.graphical.editors.helix.enable = true;
        };
      };
    }
    (config:
      let
        names = map (p: p.pname or (lib.getName p));
        sys = names config.environment.systemPackages;
        hm = names config.home-manager.users.leanuser.home.packages;
        none = bad: list: !(lib.any (n: lib.elem n bad) list);
      in
      {
        systemHasNoDevTools = none [ "alsa-tools" "hipify" "rocm-runtime" "rocm-device-libs" "minikube" "opencv" ] sys;
        helixHasNoToolchainServers = none [ "clang-tools" "lldb" "rust-analyzer" "cmake-language-server" "tree-sitter" ] hm;
        # Everything development: language servers, formatters, copilot,
        # container dev TUIs/compose, interpreters/debuggers, installer tools.
        helixIsJustTheEditor = none [ "nil" "marksman" "markdown-oxide" "vscode-langservers-extracted" "texlab" "yaml-language-server" "taplo" "github-copilot-cli" "alejandra" "nixfmt" ] hm;
        helixConfigPinsNoServer = !(lib.hasInfix "/nix/store/" (builtins.unsafeDiscardStringContext
          (lib.generators.toJSON { } config.home-manager.users.leanuser.programs.helix.languages)));
        noContainerDevTools = none [ "lazydocker" "podman-tui" "podman-compose" "docker-compose" ] sys;
        noDevDefaults = none [ "perl" "strace" "nixos-install" "nixos-enter" "nixos-generate-config" "nixos-build-vms" ] sys;
        rsyncKept = lib.elem "rsync" sys;
        rebuildKept = lib.any (n: lib.hasPrefix "nixos-rebuild" n) sys;
        plainGit = !(lib.hasInfix "with-svn" config.home-manager.users.leanuser.programs.git.package.name);
        helixKept = lib.elem "helix" hm;
        rocmSmiKept = lib.elem "rocm-smi" sys;
        alsaUtilsKept = lib.elem "alsa-utils" sys;
      });

  # One QEMU per host: libvirt, quickemu and Incus all run the host-only
  # build (x86 guests on an x86 host), instead of two extra all-architecture
  # QEMUs (~1 GiB each). And no 32-bit graphics stack without a 32-bit
  # consumer (nixpkgs' programs.steam turns it on itself).
  lean-one-qemu-no-32bit = evalClauses "lean-one-qemu-no-32bit"
    {
      networking.hostName = "test-lean-qemu";
      my = {
        hardware.gpu = "amd";
        users.vmuser = { fullName = "VM User"; description = "vm"; email = "vm@example.com"; };
        virtualisation = {
          incus.enable = true;
          vms = {
            libvirt.enable = true;
            machines.w = { owner = "vmuser"; os = "windows"; };
          };
        };
      };
    }
    (config:
      let
        qemu = config.virtualisation.libvirtd.qemu.package;
        quickemu = lib.findFirst (p: (p.pname or "") == "quickemu") null config.home-manager.users.vmuser.home.packages;
      in
      {
        libvirtHostOnly = lib.hasPrefix "qemu-host-cpu-only" qemu.name;
        quickemuSharesIt = quickemu != null && lib.hasInfix
          (builtins.unsafeDiscardStringContext qemu.outPath)
          (builtins.unsafeDiscardStringContext (quickemu.installPhase or ""));
        noFullQemuInSystem = !(lib.any (p: (p.pname or "") == "qemu") config.environment.systemPackages);
        no32BitGraphics = !config.hardware.graphics.enable32Bit;
      });

  # Runtime is lean: what nixpkgs ships for building or for features nobody
  # here uses is overridden away. Building happens in devenv, never at runtime.
  # The v4l2loopback virtual camera is OBS's, so it comes and goes with the
  # user's graphical.streaming -- there is no separate host switch to forget.
  streaming-virtual-camera = evalClauses "streaming-virtual-camera"
    {
      networking.hostName = "test-obs";
      my.users.obsuser = {
        fullName = "OBS User";
        description = "obs";
        email = "obs@example.com";
        graphical = { enable = true; streaming.enable = true; };
      };
    }
    (config: {
      obs = config.home-manager.users.obsuser.programs.obs-studio.enable;
      moduleLoaded = lib.elem "v4l2loopback" config.boot.kernelModules;
      cameraNamed = lib.hasInfix ''card_label="OBS Virtual Camera"'' config.boot.extraModprobeConfig;
      noVideoDomain = !(config.my ? video);
      # The module loads at boot; nobody needs root's modprobe through polkit.
      noModprobeGrant = !(lib.hasInfix "policykit.exec" config.security.polkit.extraConfig)
        && !(lib.hasInfix "modprobe" config.security.polkit.extraConfig);
    });

  # A host with only the base domains on carries nothing that belongs to a
  # feature it did not enable, and grants nothing root-equivalent by default.
  bare-host-defaults = evalClauses "bare-host-defaults"
    {
      networking.hostName = "test-bare";
      fileSystems."/persist" = {
        device = "/dev/disk/by-label/persist";
        fsType = "ext4";
        neededForBoot = true;
      };
      my = {
        system.enable = true;
        environment.enable = true;
        storage.impermanence.enable = true;
        users.bareuser = {
          fullName = "Bare User";
          description = "bare";
          email = "bare@example.com";
        };
      };
    }
    (config:
      let sys = map (p: p.pname or (lib.getName p)) config.environment.systemPackages;
      in {
        # Rebuilds are the owner's action, never a 04:40 timer's.
        noAutoUpgrade = !config.system.autoUpgrade.enable;
        # gpg-agent and its SSH socket are the security key's (yubico).
        noGpgAgent = !config.programs.gnupg.agent.enable;
        noSshAuthSock = !(config.environment.sessionVariables ? SSH_AUTH_SOCK);
        # EDITOR/BROWSER are per-user selections, not host store paths.
        noHostEditorBrowser = !(lib.hasInfix "helix" (config.environment.variables.EDITOR or ""))
          && !(config.environment.variables ? BROWSER)
          && !(config.environment.sessionVariables ? DEFAULT_BROWSER)
          && !(lib.elem "brave" sys);
        # Trust follows the admin role, not mere existence of an account.
        trustedByRole = lib.all (u: lib.elem u [ "root" "@wheel" ]) config.nix.settings.trusted-users
          && !(lib.elem "bareuser" config.nix.settings.trusted-users);
        noWorldWritableDevices = !(lib.hasInfix "0666" config.services.udev.extraRules);
        # A compiler cache is a build tool; the host builds nothing.
        noCcache = !config.programs.ccache.enable && !(lib.elem "ccache" sys)
          && !(config.environment.sessionVariables ? CCACHE_DIR);
        # Devices, GPU stacks and firmware are turned on by what needs them.
        noDeviceServices = !config.services.trezord.enable && !config.services.usbmuxd.enable;
        fwupdKept = config.services.fwupd.enable;
        noGraphicsStack = !config.hardware.graphics.enable;
        noFirmwareWithoutProfile = !config.hardware.enableRedistributableFirmware;
        noDevenvCache = !(lib.hasInfix "devenv.cachix" config.nix.extraOptions)
          && !(lib.any (lib.hasInfix "devenv.cachix") (config.nix.settings.extra-substituters or [ ]));
        # The base CLI set is curl, wget, tree and mc; the rest are per-user apps.
        baseCliOnly = !(lib.any (n: lib.elem n sys) [ "yazi" "helix" "fastfetch" "btop" "screen" "sops" "password-store" "pass-env" ])
          && lib.all (n: lib.elem n sys) [ "curl" "wget" "tree" "mc" ];
        notAdmin = !(lib.elem "wheel" config.users.users.bareuser.extraGroups);
      });

  # sops and pass belong to the person who edits the store, not the host:
  # my.secrets decrypts at activation without the CLI.
  secrets-tools-per-user = evalClauses "secrets-tools-per-user"
    {
      networking.hostName = "test-secrets-tools";
      my = {
        system.enable = true;
        secrets.enable = true;
        users.editor = {
          fullName = "Editor";
          description = "editor";
          email = "editor@example.com";
          apps.security = {
            secrets.sops.enable = true;
            passwords.pass.enable = true;
          };
        };
        users.other = {
          fullName = "Other";
          description = "other";
          email = "other@example.com";
        };
      };
    }
    (config:
      let
        names = ps: map (p: p.pname or (lib.getName p)) ps;
        sys = names config.environment.systemPackages;
        hm = u: names config.home-manager.users.${u}.home.packages;
      in
      {
        notOnHost = !(lib.elem "sops" sys) && !(lib.elem "pass-env" sys);
        editorHasBoth = lib.elem "sops" (hm "editor") && lib.elem "pass-env" (hm "editor");
        otherHasNeither = !(lib.elem "sops" (hm "other")) && !(lib.elem "pass-env" (hm "other"));
      });

  yubico-owns-gpg-agent = evalClauses "yubico-owns-gpg-agent"
    {
      networking.hostName = "test-yubico-agent";
      my = {
        system.enable = true;
        hardware.securityKeys.yubico.enable = true;
        users.keyuser = {
          fullName = "Key User";
          description = "key";
          email = "key@example.com";
        };
      };
    }
    (config: {
      agent = config.programs.gnupg.agent.enable && config.programs.gnupg.agent.enableSSHSupport;
      sshAuthSock = config.environment.sessionVariables ? SSH_AUTH_SOCK;
    });

  # The NVIDIA profile is the driver, not a CUDA toolchain: no nvcc on the
  # host, no global cudaSupport rebuilding everything with CUDA, and no
  # world-writable device nodes. CUDA arrives with the thing that uses it.
  lean-nvidia = evalClauses "lean-nvidia"
    {
      networking.hostName = "test-nvidia";
      my = {
        system.enable = true;
        hardware.gpu = "nvidia";
        ai = { enable = true; ollama.enable = true; };
        users.gpuuser = {
          fullName = "GPU User";
          description = "gpu";
          email = "gpu@example.com";
        };
      };
    }
    (config:
      let sys = map (p: p.pname or (lib.getName p)) config.environment.systemPackages;
      in {
        noToolkit = !(lib.any (n: lib.elem n sys) [ "cudatoolkit" "cuda_nvcc" "cuda-merged" ]);
        noGlobalCuda = !(config.nixpkgs.config.cudaSupport or false);
        noWorldWritableDevices = !(lib.hasInfix "0666" config.services.udev.extraRules);
        # ollama-cuda carries no marker of its own; the CUDA licence is granted
        # only on the CUDA branch, so its presence is the branch.
        cudaLicenceWithOllama = lib.elem "CUDA EULA" config.my.system.allowedUnfreeLicenses;
        # One kernel module build: the open one hardware.nvidia adds.
        openModuleOnly = lib.any (p: lib.hasPrefix "nvidia-open" p.name) config.boot.extraModulePackages
          && !(lib.any (p: lib.hasPrefix "nvidia-x11" p.name) config.boot.extraModulePackages);
        drmLoaded = lib.elem "nvidia_drm" config.boot.kernelModules;
      });

  lean-nvidia-no-ai = evalClauses "lean-nvidia-no-ai"
    {
      networking.hostName = "test-nvidia-plain";
      my = {
        system.enable = true;
        hardware.gpu = "nvidia";
        users.gpuuser = {
          fullName = "GPU User";
          description = "gpu";
          email = "gpu@example.com";
        };
      };
    }
    (config: {
      noCudaLicence = !(lib.elem "CUDA EULA" config.my.system.allowedUnfreeLicenses);
      noCudaUnfree = !(lib.any (lib.hasPrefix "cuda") config.my.system.allowedUnfreePackages);
    });

  # The Stream Deck is a device: its UI follows the device switch, and only
  # its OBS buttons follow OBS. Its Qt fixes stay inside its own wrapper.
  streamdeck-without-obs = evalClauses "streamdeck-without-obs"
    {
      networking.hostName = "test-deck";
      my = {
        hardware.peripherals.elgato.streamdeck.enable = true;
        users.deckuser = {
          fullName = "Deck User";
          description = "deck";
          email = "deck@example.com";
          graphical.enable = true;
        };
      };
    }
    (config:
      let hm = config.home-manager.users.deckuser;
      in {
        ui = lib.elem "streamdeck-ui" (map (p: p.pname or "") hm.home.packages);
        micButton = hm.home.file ? ".local/bin/mic-toggle";
        noObsButtons = !(hm.home.file ? ".local/bin/obs-virtualcam-toggle")
          && !(lib.hasInfix "obs-virtualcam" (hm.home.file.".streamdeck_ui.json".text or ""));
        noGlobalQtHack = !(config.environment.sessionVariables ? QT_QPA_PLATFORM_PLUGIN_PATH)
          && !(config.environment.sessionVariables ? QT_LOGGING_RULES);
      });

  streamdeck-with-obs = evalClauses "streamdeck-with-obs"
    {
      networking.hostName = "test-deck-obs";
      my = {
        hardware.peripherals.elgato.streamdeck.enable = true;
        users.deckuser = {
          fullName = "Deck User";
          description = "deck";
          email = "deck@example.com";
          graphical = { enable = true; streaming.enable = true; };
        };
      };
    }
    (config:
      let hm = config.home-manager.users.deckuser;
      in {
        obsButtons = hm.home.file ? ".local/bin/obs-virtualcam-toggle"
          && lib.hasInfix "obs-virtualcam" (hm.home.file.".streamdeck_ui.json".text or "");
      });

  # The per-user Hyprland switch decides the system-level Hyprland too.
  hyprland-follows-user-switch = evalClauses "hyprland-follows-user-switch"
    {
      networking.hostName = "test-no-hypr";
      my.users.nohypr = {
        fullName = "No Hypr";
        description = "nohypr";
        email = "nohypr@example.com";
        graphical.enable = true;
        apps.graphical.windowManagers.hyprland.enable = false;
      };
    }
    (config: {
      noHyprland = !config.programs.hyprland.enable;
      noSession = !(lib.any (p: lib.elem "hyprland" (p.providedSessions or [ ])) config.services.displayManager.sessionPackages);
    });

  streaming-virtual-camera-off = evalClauses "streaming-virtual-camera-off"
    {
      networking.hostName = "test-no-obs";
      my.users.plainuser = {
        fullName = "Plain User";
        description = "plain";
        email = "plain@example.com";
        graphical.enable = true;
      };
    }
    (config: {
      noModule = !(lib.elem "v4l2loopback" config.boot.kernelModules);
      noOptions = !(lib.hasInfix "v4l2loopback" config.boot.extraModprobeConfig);
      noPackage = !(lib.any (p: lib.hasPrefix "v4l2loopback" (p.name or "")) config.boot.extraModulePackages);
    });

  lean-runtime-overrides = evalClauses "lean-runtime-overrides"
    {
      networking.hostName = "test-lean-runtime";
      my.users.leanuser = {
        fullName = "Lean User";
        description = "lean";
        email = "lean@example.com";
        graphical = { enable = true; webapps.enable = true; };
      };
    }
    (config:
      let
        noRef = needle: s: !(lib.hasInfix needle (builtins.unsafeDiscardStringContext s));
        hyprland = config.programs.hyprland.package;
        browser = config.home-manager.users.leanuser.programs.webapps.browser;
        sys = map (p: p.pname or (lib.getName p)) config.environment.systemPackages;
      in
      {
        # hyprpm's plugin toolchain (binutils, pkgconf) is not on every
        # program's PATH; the dialogs Hyprland itself spawns still are.
        hyprlandNoBuildTools = noRef "binutils" (hyprland.postInstall or "")
          && noRef "pkgconf" (hyprland.postInstall or "");
        hyprlandDialogsKept = lib.elem "hyprland-guiutils" sys;
        noSpeechService = !config.services.speechd.enable;
        webappsOnBrave = (browser.pname or "") == "brave";
        braveNoSpeech = noRef "speech-dispatcher" (browser.installPhase or "");
        noChromiumAllowed = !(lib.elem "chromium-unwrapped" config.my.system.allowedUnfreePackages);
      });

  # The dev workspace: one devenv at ~/Code carries the development CLIs
  # (forge CLIs, git companions), loaded by direnv without a manual allow and
  # reaching repos that have their own .envrc. The host itself carries none,
  # and git's config names them bare so it works without them outside ~/Code.
  dev-workspace = evalClauses "dev-workspace"
    {
      networking.hostName = "test-dev-workspace";
      my.users.devuser = {
        fullName = "Dev User";
        description = "dev";
        email = "dev@example.com";
        dev.enable = true;
        apps.dev.tools.git.protocol = "https";
        apps.dev.tools.devenv.workspace.directory = "Code";
      };
    }
    (config:
      let
        hm = config.home-manager.users.devuser;
        file = p: hm.home.file.${p}.text or "";
        names = map (p: p.pname or (lib.getName p)) hm.home.packages;
        ini = hm.programs.git.iniContent;
        noStore = s: !(lib.hasInfix "/nix/store/" (builtins.unsafeDiscardStringContext s));
      in
      {
        files = hm.home.file ? "Code/devenv.nix" && hm.home.file ? "Code/devenv.yaml" && hm.home.file ? "Code/.envrc";
        packagesInDevenv = lib.all (p: lib.hasInfix p (file "Code/devenv.nix")) [ "gh" "glab" "lazygit" "delta" "git-lfs" "jujutsu" ];
        envrcUsesDevenv = lib.hasInfix "use devenv" (file "Code/.envrc");
        allowedWithoutPrompt = lib.elem "/home/devuser/Code" (hm.programs.direnv.config.whitelist.prefix or [ ]);
        reachesNestedRepos = lib.hasInfix "/home/devuser/Code/.devenv/profile/bin" (hm.programs.direnv.stdlib or "");
        hostCarriesNone = !(lib.any (n: lib.elem n names) [ "gh" "glab" "lazygit" "delta" "git-lfs" "jujutsu" ]);
        gitNamesThemBare = noStore (ini.credential."https://github.com".helper or "")
          && noStore (ini.core.pager or "") && noStore (ini.filter.lfs.process or "");
        lfsNotRequired = (ini.filter.lfs.required or true) == false;
        # jj's config is still written (HM's own module stays off; see
        # my/users/apps/jujutsu), and it still carries the merged settings.
        jjConfigKept = hm.xdg.configFile ? "jj/config.toml" && !hm.programs.jujutsu.enable
          && hm.programs.jujutsu.settings.git.auto-local-bookmark;
      });

  vm-quickemu-off = evalAssert "vm-quickemu-off"
    {
      networking.hostName = "test-vm-off";
      my.users.vmuser = { fullName = "VM User"; description = "vm"; email = "vm@example.com"; };
    }
    (config:
      !(lib.any (p: (p.pname or "") == "quickemu") config.home-manager.users.vmuser.home.packages)
      && !(lib.hasInfix "ignore_msrs" config.boot.extraModprobeConfig));

  vm-refuses-unknown-owner = evalAssert "vm-refuses-unknown-owner"
    {
      networking.hostName = "test-vm-owner";
      my.virtualisation.vms.machines.w = { owner = "nobody-here"; os = "linux"; };
    }
    (config: lib.any (a: !a.assertion && lib.hasInfix "nobody-here" a.message) config.assertions);

  vm-refuses-secureboot-without-uefi = evalAssert "vm-refuses-secureboot-without-uefi"
    {
      networking.hostName = "test-vm-sb";
      my.users.vmuser = { fullName = "VM User"; description = "vm"; email = "vm@example.com"; };
      my.virtualisation.vms.machines.w = {
        owner = "vmuser";
        os = "linux";
        firmware = { uefi = false; secureBoot = true; };
      };
    }
    (config: lib.any (a: !a.assertion && lib.hasInfix "secureBoot" a.message) config.assertions);

  peripheral-elgato-4k-x-uvcvideo-off = evalAssert "peripheral-elgato-4k-x-uvcvideo-off"
    {
      networking.hostName = "test-4kx";
      my.hardware.peripherals.elgato.game-capture-4k-x = { enable = true; uvcvideo.patch = false; };
    }
    (config: !builtins.any (p: (p.pname or "") == "uvcvideo-elgato-4k-x") config.boot.extraModulePackages);

  psu-corsair-hx1200i = evalAssert "psu-corsair-hx1200i"
    {
      imports = [ (kernelAt "7.2.6") ];
      networking.hostName = "test-psu";
      my.hardware.powerSupplies.corsair.hx1200i.enable = true;
    }
    (config: builtins.elem "corsair-psu" config.boot.kernelModules
      && builtins.any (p: (p.pname or "") == "lm-sensors") config.environment.systemPackages
      && failing "powerSupplies" config == [ ]);

  # corsair-psu learned 0x1c27 in 6.17 (6082bfe47795); an older kernel binds
  # nothing, so the profile refuses it rather than silently showing no sensors.
  psu-corsair-hx1200i-refuses-old-kernel = displayRefuses "psu-corsair-hx1200i-refuses-old-kernel" "6.17"
    {
      imports = [ (kernelAt "6.12.0") ];
      my.hardware.powerSupplies.corsair.hx1200i.enable = true;
    };

  display-hdmi-frl-7-2 = evalAssert "display-hdmi-frl-7-2"
    {
      imports = [ (kernelAt "7.2.6") ];
      networking.hostName = "test-frl";
      my.hardware = { gpu = "amd"; display.hdmiFrl.enable = true; };
    }
    (config: config.boot.kernelPackages.kernel.version == "7.2.6"
      && builtins.elem "amdgpu.dc_feature_mask=0x402" config.boot.kernelParams);

  display-hdmi-frl-7-4 = evalAssert "display-hdmi-frl-7-4"
    {
      imports = [ (kernelAt "7.4.0") ];
      networking.hostName = "test-frl";
      my.hardware = { gpu = "amd"; display.hdmiFrl.enable = true; };
    }
    (config: config.boot.kernelPackages.kernel.version == "7.4.0"
      && !lib.any (lib.hasPrefix "amdgpu.dc_feature_mask") config.boot.kernelParams);

  display-hdmi-frl-off = evalAssert "display-hdmi-frl-off"
    {
      imports = [ (kernelAt "7.2.6") ];
      networking.hostName = "test-frl";
      my.hardware.gpu = "amd";
    }
    (config: !lib.any (lib.hasPrefix "amdgpu.dc_feature_mask") config.boot.kernelParams);

  display-refuses-frl-without-amd = displayRefuses "display-refuses-frl-without-amd" "hdmiFrl"
    { my.hardware = { gpu = "nvidia"; display.hdmiFrl.enable = true; }; };

  # (g) What the domain refuses.
  display-refuses-twins = displayRefuses "display-refuses-twins" "set serial or output"
    { my.hardware.display.monitors.dell.aw3225qf = { left = { }; right = { }; }; };

  # Hyprland matches desc: as a PREFIX, so a serial-less selector also catches
  # the serialled panel of the same model.
  display-refuses-prefix-twins = displayRefuses "display-refuses-prefix-twins" "would all match"
    { my.hardware.display.monitors.dell.aw3225qf = { left = { }; right.serial = "SN1"; }; };

  display-refuses-duplicate-name = displayRefuses "display-refuses-duplicate-name" "declared more than once"
    {
      my.hardware.display.monitors = {
        dell.aw3225qf.main = { };
        generic.main.output = "DP-2";
      };
    };

  display-refuses-unknown-layout-name = displayRefuses "display-refuses-unknown-layout-name" "no monitor instance is named \"ghost\""
    { my.hardware.display.layout.ghost = { }; };

  display-refuses-cycle = displayRefuses "display-refuses-cycle" "placement cycle"
    {
      my.hardware.display = {
        monitors.dell.aw3225qf = { a.output = "DP-1"; b.output = "DP-2"; };
        layout = { a.position.rightOf = "b"; b.position.rightOf = "a"; };
      };
    };

  display-refuses-overlap = displayRefuses "display-refuses-overlap" "overlap"
    {
      my.hardware.display = {
        monitors.dell.aw3225qf = { a.output = "DP-1"; b.output = "DP-2"; };
        layout = { a.position = { x = 0; y = 0; }; b.position = { x = 100; y = 0; }; };
      };
    };

  display-refuses-hdr-8bit = displayRefuses "display-refuses-hdr-8bit" "HDR needs bitDepth = 10"
    { my.hardware.display.monitors.dell.aw3225qf.main.bitDepth = 8; };

  display-refuses-icc-with-hdr = displayRefuses "display-refuses-icc-with-hdr" "icc"
    { my.hardware.display.monitors.dell.aw3225qf.main.hdr.icc = "/etc/main.icc"; };

  display-refuses-fractional-scale = displayRefuses "display-refuses-fractional-scale" "whole logical pixels"
    {
      my.hardware.display = {
        monitors.generic.side = { output = "DP-2"; mode = { width = 2560; height = 1440; refresh = 60; }; };
        layout.side.scale = 1.5;
      };
    };

  display-refuses-generic-without-identity = displayRefuses "display-refuses-generic-without-identity" "set output, or make and model"
    { my.hardware.display.monitors.generic.anon = { }; };

  display-refuses-hyprlang = displayRefuses "display-refuses-hyprlang" "cannot render my.hardware.display"
    {
      my = {
        theming = { enable = false; vogix.enable = false; };
        hardware.display.monitors.dell.aw3225qf.main = { };
        users.hypruser = {
          fullName = "Hypr User";
          description = "hypr";
          email = "hypr@example.com";
          graphical.enable = true;
          apps.graphical.windowManagers.hyprland = { enable = true; configType = "hyprlang"; };
        };
      };
    };

  # --- placement batch 2 ------------------------------------------------------

  # Groups follow each user's own switches: a second user who turned nothing on
  # gets none of the feature groups, nobody gets raw disks or every input
  # device, every granted group exists, and only an admin is in wheel (and only
  # an admin gets the passwordless rebuild).
  per-user-groups = evalClauses "per-user-groups"
    {
      networking.hostName = "test-groups";
      my = {
        security = { enable = true; nopasswdRebuild = true; passwordAuthOnly = true; };
        hardware.peripherals = {
          elgato.streamdeck.enable = true;
          sipeed.tangPrimer25k = { enable = true; users = [ "alice" ]; };
        };
        users = {
          alice = {
            fullName = "Alice";
            description = "alice";
            email = "alice@example.com";
            admin = true;
            dev.enable = true;
            graphical = { enable = true; streaming.enable = true; };
          };
          bob = {
            fullName = "Bob";
            description = "bob";
            email = "bob@example.com";
            # vogix's own NixOS module adds input and uinput to every user it
            # themes (its input engine); that grant is vogix's, not mynixos'.
            theming.vogix.enable = false;
          };
        };
      };
    }
    (config:
      let
        groupsOf = u: config.users.users.${u}.extraGroups;
        has = u: g: lib.elem g (groupsOf u);
        sudoUsers = lib.concatMap (r: r.users or [ ]) config.security.sudo.extraRules;
      in
      {
        # `audio` is my.hardware.audio's, a host device every account uses.
        bobNoFeatureGroups = !(lib.any (has "bob") [ "disk" "dialout" "input" "gpu" "video" "render" "udev" "usb" ]);
        aliceGraphical = has "alice" "video" && has "alice" "render";
        nobodyRawDisk = !(has "alice" "disk") && !(has "bob" "disk");
        noPhantomGroups = !(lib.any (has "alice") [ "gpu" "udev" "usb" ]);
        allGroupsExist = lib.all
          (u: lib.all (g: config.users.groups ? ${g}) (groupsOf u))
          [ "alice" "bob" ];
        noStreamdeckGroup = !(config.users.groups ? streamdeck);
        serialForItsUsers = has "alice" "dialout" && !(has "bob" "dialout");
        wheelIsAdmin = has "alice" "wheel" && !(has "bob" "wheel");
        rebuildForAdmins = lib.elem "alice" sudoUsers && !(lib.elem "bob" sudoUsers);
      });

  # Trezor and iOS are devices a host turns on, never core defaults.
  peripheral-devices-opt-in = evalClauses "peripheral-devices-opt-in"
    {
      networking.hostName = "test-devices";
      my.hardware.peripherals = {
        trezor.enable = true;
        apple.ios.enable = true;
      };
    }
    (config: {
      trezord = config.services.trezord.enable;
      usbmuxd = config.services.usbmuxd.enable;
    });

  # devenv's binary cache arrives with devenv.
  devenv-owns-its-cache = evalClauses "devenv-owns-its-cache"
    {
      networking.hostName = "test-devenv-cache";
      my = {
        system.enable = true;
        users.devuser = {
          fullName = "Dev User";
          description = "dev";
          email = "dev@example.com";
          apps.dev.tools.devenv.enable = true;
        };
      };
    }
    (config: {
      substituter = lib.elem "https://devenv.cachix.org" (config.nix.settings.extra-substituters or [ ]);
      key = lib.any (lib.hasPrefix "devenv.cachix.org-1:") (config.nix.settings.extra-trusted-public-keys or [ ]);
      nixosCacheKept = lib.elem "https://cache.nixos.org/" config.nix.settings.substituters;
    });

  # Forensics is its own domain: it does not depend on my.system, and the
  # knobs that only gated it are gone.
  forensics-own-domain = evalClauses "forensics-own-domain"
    {
      networking.hostName = "test-forensics";
      my.system.enable = false;
    }
    (config: {
      journald = (config.services.journald.settings.Journal.Storage or null) == "persistent";
      ramoops = lib.elem "ramoops" config.boot.kernelModules
        && lib.elem "ramoops.mem_name=oops" config.boot.kernelParams;
      pstore = config.systemd.services ? forensics-pstore-persist;
      coredump = config.systemd.coredump.enable;
      noSystemdKnob = !(config.my.system ? systemd);
      noUdevKnob = !(config.my.system ? udev);
    });

  # PipeWire lives under my.hardware.audio; the Legion speaker unit is the
  # Legion's, and the CoreAudio sample-rate agent is declared on darwin only.
  audio-pipewire = evalClauses "audio-pipewire"
    {
      networking.hostName = "test-audio";
      my.hardware.audio.enable = true;
    }
    (config: {
      pipewire = config.services.pipewire.enable;
      noHollowSpeakerUnit = !(config.systemd.services ? fix-audio-speaker);
      noDarwinKnob = !(config.my.hardware.audio ? maxSampleRate) && !(config.my.hardware.audio ? darwin);
    });

  # Brave's GPU log rides on the amdgpu capture, but Brave owns that half.
  brave-gpu-log-snapshot = evalClauses "brave-gpu-log-snapshot"
    {
      networking.hostName = "test-brave-gpu";
      my = {
        hardware.gpu = "amd";
        users.braveuser = {
          fullName = "Brave User";
          description = "brave";
          email = "brave@example.com";
          graphical.enable = true;
        };
      };
    }
    (config:
      let unit = config.systemd.services."amdgpu-devcoredump-capture@".serviceConfig;
      in {
        snapshotWithBrave = lib.hasInfix "brave-gpu-log-snapshot" (toString (unit.ExecStartPre or ""));
      });

  amd-capture-without-brave = evalClauses "amd-capture-without-brave"
    {
      networking.hostName = "test-amd-nobrave";
      my.hardware.gpu = "amd";
    }
    (config:
      let unit = config.systemd.services."amdgpu-devcoredump-capture@".serviceConfig;
      in {
        capture = unit ? ExecStart;
        noBraveSnapshot = !(lib.hasInfix "brave" (toString (unit.ExecStartPre or "")));
      });

  # The window manager carries no audio mixer, media player or tray apps of
  # its own; those follow their app switches and services. With no browser
  # or terminal selected, nothing is hard-coded in their place.
  hyprland-own-packages-only = evalClauses "hyprland-own-packages-only"
    {
      networking.hostName = "test-hypr-pkgs";
      networking.networkmanager.enable = false;
      services.udisks2.enable = false;
      my.users.hypruser = {
        fullName = "Hypr User";
        description = "hypr";
        email = "hypr@example.com";
        graphical.enable = true;
        environment = { BROWSER = null; TERMINAL = null; };
      };
    }
    (config:
      let
        hm = config.home-manager.users.hypruser;
        names = map (p: p.pname or (lib.getName p)) hm.home.packages;
        envNames = map (e: lib.head (e._args or [ "" ])) (hm.wayland.windowManager.hyprland.settings.env or [ ]);
      in
      {
        noMixer = !(lib.elem "pavucontrol" names) && !(lib.elem "pamixer" names);
        noVlc = !(lib.elem "vlc" names);
        noTrayWithoutServices = !(lib.elem "udiskie" names) && !(lib.elem "network-manager-applet" names);
        noBrowserFallback = !(lib.elem "BROWSER" envNames);
        noTerminalFallback = !(lib.elem "TERMINAL" envNames);
        noDefaultsTree = !(config.my.users.hypruser ? defaults);
      });

  hyprland-media-apps = evalClauses "hyprland-media-apps"
    {
      networking.hostName = "test-hypr-media";
      networking.networkmanager.enable = true;
      services.udisks2.enable = true;
      my.users.mediauser = {
        fullName = "Media User";
        description = "media";
        email = "media@example.com";
        graphical = { enable = true; media.enable = true; };
      };
    }
    (config:
      let names = map (p: p.pname or (lib.getName p)) config.home-manager.users.mediauser.home.packages;
      in {
        mixer = lib.elem "pavucontrol" names && lib.elem "pamixer" names;
        vlc = lib.elem "vlc" names;
        nmApplet = lib.elem "network-manager-applet" names;
        udiskie = lib.elem "udiskie" names;
      });

  # The YubiKey module is key plumbing; desktop keyring policy is the
  # desktop's and password managers are per-user apps.
  yubico-key-plumbing-only = evalClauses "yubico-key-plumbing-only"
    {
      networking.hostName = "test-yubico-plain";
      my = {
        hardware.securityKeys.yubico.enable = true;
        users.keyuser = {
          fullName = "Key User";
          description = "key";
          email = "key@example.com";
          # A user WITH a key: the per-user half of the module is what used
          # to install gopass and pass-import. Placeholder, evaluation only.
          yubikeys = [{
            serial = "1";
            keyId = "AAAAAAAA";
            fingerprint = "AAAA";
            sshKeygrip = "GRIP";
            publicKeyPath = ./module-eval.nix;
            u2fKeyHandle = "HANDLE";
            u2fPublicKey = "PUB";
          }];
        };
      };
    }
    (config:
      let
        sys = map (p: p.pname or (lib.getName p)) config.environment.systemPackages;
        hm = map (p: p.pname or (lib.getName p)) config.home-manager.users.keyuser.home.packages;
        managers = [ "gopass" "gopass-jsonapi" "pass-import" "pass-env" "password-store" "ripasso-cursive" "libsecret" ];
      in
      {
        noKeyringPolicy = !(config.environment.sessionVariables ? DISABLE_GNOME_KEYRING)
          && !config.services.gnome.glib-networking.enable;
        noPasswordManagers = !(lib.any (n: lib.elem n sys) managers);
        noUserPasswordManagers = !(lib.any (n: lib.elem n hm) managers);
        pcscd = config.services.pcscd.enable;
      });

  graphical-keyring-policy = evalClauses "graphical-keyring-policy"
    {
      networking.hostName = "test-keyring";
      my.users.desk = {
        fullName = "Desk User";
        description = "desk";
        email = "desk@example.com";
        graphical.enable = true;
        apps.security.passwords = { gopass.enable = true; ripasso.enable = true; pass.enable = true; };
      };
    }
    (config:
      let names = map (p: p.pname or (lib.getName p)) config.home-manager.users.desk.home.packages;
      in {
        keyringOff = !config.services.gnome.gnome-keyring.enable
          && config.environment.sessionVariables.DISABLE_GNOME_KEYRING or null == "1";
        glibNetworking = config.services.gnome.glib-networking.enable;
        dconf = config.programs.dconf.enable;
        passwordApps = lib.all (n: lib.elem n names) [ "gopass" "ripasso-cursive" "pass-env" ];
      });

  # The hardware profiles bring firmware only when the profile is the machine.
  profiles-firmware-gated = evalClauses "profiles-firmware-gated"
    {
      networking.hostName = "test-profile";
      my.hardware.motherboards.gigabyte.trx50-aero-d.enable = true;
    }
    (config: {
      firmware = config.hardware.enableRedistributableFirmware;
    });

  # Every module platforms/common.nix imports must be meaningful on darwin:
  # none of them may read a Linux-only option through `or`.
  common-imports-portable = evalAssert "common-imports-portable"
    { networking.hostName = "test-common"; }
    (_:
      let common = builtins.readFile ../platforms/common.nix;
      in !(lib.any (p: lib.hasInfix p common) [
        "users/graphical/media/mynixos.nix"
        "users/webapps/mynixos.nix"
        "../my/users/defaults\n"
      ])
      && !(lib.hasInfix "my.infra" (builtins.readFile ../my/users/apps/dev/radicle/insecure.nix)));
}
