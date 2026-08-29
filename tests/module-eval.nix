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
}
