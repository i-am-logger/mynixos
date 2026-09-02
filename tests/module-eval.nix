{ lib
, nixpkgs
, system
, self
, inputs
}:

let
  testLib = import ./lib.nix { inherit lib nixpkgs system self inputs; };
  inherit (testLib) pkgs specialArgs baseModules baseConfig;

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

  # Like evalAssert, but for a ROLE -- a system mkSystem already built, rather
  # than a module list this file assembles. A role brings its own module set
  # (platforms/oci.nix) and its own architecture, so baseModules/baseConfig do
  # not apply: handing it those would test a hand-built lookalike instead of
  # what a consumer actually gets from `self.lib.roles.*`.
  roleAssert = name: role: predicate:
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
      && !hm.programs.zellij.enable
      && !hm.programs.tmux.enable);

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
        config.my.dev.containers.backend == "podman"
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
        my.dev.containers.backend = "docker";
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
        my.dev.containers.backend = "docker";
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
          apps.graphical.windowManagers.hyprland.enable = true;
        };
      };
    }
    (config:
      let
        hm = config.home-manager.users.hypruser;
        text = hm.xdg.configFile."hypr/hyprland.conf".text;
      in
      hm.wayland.windowManager.hyprland.configType == "hyprlang"
      && lib.hasInfix "natural_scroll=yes" text
      && lib.hasInfix "hyprctl --batch" text
      && !(hm.xdg.configFile ? "hypr/hyprland.lua"));

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
      && lib.hasInfix ''["name"] = "slack-menus"'' text
      && lib.hasInfix ''hl.exec_cmd("1password --silent")'' text
      && !(hm.xdg.configFile ? "hypr/hyprland.conf"));

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
      # What platforms/oci.nix does to every role.
      services.openssh.enable = lib.mkForce false;
    }
    (config:
      !config.services.openssh.enable
      && config.networking.firewall.interfaces.tailscale0.allowedTCPPorts == [ 9999 ]);

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
  oci-radicle-builder = roleAssert "oci-radicle-builder"
    (self.lib.roles.radicle.builder {
      inherit system;
      publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBgFMhajUng+Rjj/sCFXI9PzG8BQjru2n7JgUVF1Kbv5";
      trustedNids = [ "z6MkuEBniT9BRGVjKUUV2Yi8dcEHzbDAn1fD5meaZ33bNMJV" ];
      connect = [ "z6MkSeed@radicle-seed.example.ts.net:8776" ];
    })
    (config:
      # A machine, not a process: an init, and the nix DB loader that makes nix
      # usable inside a builder at all.
      config.boot.isContainer
      && config.systemd.services ? register-nix-paths
      && !config.boot.loader.systemd-boot.enable
      && !config.boot.lanzaboote.enable

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
      && !config.services.openssh.enable
      && config.networking.firewall.interfaces.tailscale0.allowedTCPPorts == [ 8776 8782 ]
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

  oci-radicle-seed = roleAssert "oci-radicle-seed"
    (self.lib.roles.radicle.seed {
      inherit system;
      publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBgFMhajUng+Rjj/sCFXI9PzG8BQjru2n7JgUVF1Kbv5";
      externalAddresses = [ "radicle-seed.example.ts.net:8776" ];
      seedHostname = "radicle-seed.example.ts.net";
    })
    (config:
      config.boot.isContainer
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
}
