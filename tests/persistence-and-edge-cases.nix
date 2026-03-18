# Tests for persistence aggregation, partial users, display manager types,
# network defense, and other edge cases not covered by existing tests.
#
# Usage: called from flake.nix checks via forAllSystems

{ self, inputs, system }:

let
  inherit (inputs.nixpkgs) lib;
  pkgs = import inputs.nixpkgs {
    inherit system;
    config.allowUnfree = true;
  };

  # Helper: evaluate a NixOS configuration with the mynixos module
  evalSystem =
    { name
    , myConfig
    , extraModules ? [ ]
    }:
    lib.nixosSystem {
      specialArgs = {
        inherit (inputs) vogix;
        inherit pkgs;
      };
      modules = [
        self.nixosModules.default
        inputs.home-manager.nixosModules.home-manager
        inputs.sops-nix.nixosModules.sops
        "${inputs.nixpkgs}/nixos/modules/misc/nixpkgs/read-only.nix"
        {
          nixpkgs.pkgs = pkgs;
          networking.hostName = name;
          fileSystems."/" = { device = "/dev/sda1"; fsType = "ext4"; };
          boot.loader.grub.device = "/dev/sda";
          system.stateVersion = "24.11";

          home-manager = {
            useUserPackages = true;
            backupFileExtension = "backup";
            extraSpecialArgs = { inherit inputs; };
            sharedModules = [{
              home.stateVersion = "24.11";
            }];
            users = { };
          };

          my = myConfig // {
            themes.enable = false;
          };
        }
      ] ++ extraModules;
    };

  mkSmokeTest =
    { name
    , myConfig
    , extraModules ? [ ]
    , assertions ? (_config: true)
    }:
    let
      eval = evalSystem { inherit name myConfig extraModules; };
      inherit (eval) config;
      evalOk = builtins.seq config.system.build.toplevel true;
      assertionResult = assertions config;
    in
    assert evalOk;
    assert lib.assertMsg assertionResult "smoke-test-${name}: assertions failed";
    pkgs.runCommand "smoke-test-${name}" { } ''
      echo "PASS: ${name}"
      mkdir -p $out
      echo "${name}: ok" > $out/result
    '';

in
{
  # --- Persistence Aggregation Tests ---

  # Test: App persistence directories are correctly aggregated per-user
  smoke-persistence-aggregation = mkSmokeTest {
    name = "test-persistence-aggregation";
    myConfig = {
      system.enable = true;
      system.hostname = "test-persistence-aggregation";
      users.testuser = {
        fullName = "Test User";
        description = "Test User";
        email = "test@example.com";
        terminal.enable = true;
      };
    };
    assertions = config:
      let
        agg = config.my.system.persistence.aggregated.testuser;
      in
      # Bash (terminal default) should contribute .bash_history
      builtins.elem ".bash_history" agg.files
      # Bash should appear in the aggregated apps list
      && builtins.any (a: lib.hasSuffix "bash" a) agg.apps
      # Starship (terminal default) should contribute .config/starship
      && builtins.elem ".config/starship" agg.directories;
  };

  # Test: Multi-user aggregation keeps persistence separate per user
  smoke-persistence-multi-user = mkSmokeTest {
    name = "test-persistence-multi-user";
    myConfig = {
      system.enable = true;
      system.hostname = "test-persistence-multi-user";
      users.alice = {
        fullName = "Alice";
        description = "Alice";
        email = "alice@example.com";
        graphical.enable = true;
        terminal.enable = true;
      };
      users.bob = {
        fullName = "Bob";
        description = "Bob";
        email = "bob@example.com";
        terminal.enable = true;
      };
    };
    assertions = config:
      let
        aliceAgg = config.my.system.persistence.aggregated.alice;
        bobAgg = config.my.system.persistence.aggregated.bob;
      in
      # Alice has graphical, so she should have brave browser persistence
      builtins.elem ".config/BraveSoftware" aliceAgg.directories
      # Bob does NOT have graphical, so no brave persistence
      && !(builtins.elem ".config/BraveSoftware" bobAgg.directories)
      # Both have terminal, so both should have bash history
      && builtins.elem ".bash_history" aliceAgg.files
      && builtins.elem ".bash_history" bobAgg.files;
  };

  # Test: Disabling persistence for an app excludes it from aggregation
  smoke-persistence-disabled = mkSmokeTest {
    name = "test-persistence-disabled";
    myConfig = {
      system.enable = true;
      system.hostname = "test-persistence-disabled";
      users.testuser = {
        fullName = "Test User";
        description = "Test User";
        email = "test@example.com";
        terminal.enable = true;
        apps.terminal.shells.bash.persisted = false;
      };
    };
    assertions = config:
      let
        agg = config.my.system.persistence.aggregated.testuser;
      in
      # Bash persistence disabled, so .bash_history should NOT be aggregated
        !(builtins.elem ".bash_history" agg.files);
  };

  # Test: Disabling an app entirely excludes it from aggregation
  smoke-persistence-app-disabled = mkSmokeTest {
    name = "test-persistence-app-disabled";
    myConfig = {
      system.enable = true;
      system.hostname = "test-persistence-app-disabled";
      users.testuser = {
        fullName = "Test User";
        description = "Test User";
        email = "test@example.com";
        terminal.enable = true;
        apps.terminal.shells.bash.enable = false;
      };
    };
    assertions = config:
      let
        agg = config.my.system.persistence.aggregated.testuser;
      in
      # Bash disabled entirely, so .bash_history should NOT appear
      !(builtins.elem ".bash_history" agg.files)
      # And bash should NOT appear in the apps list
      && !(builtins.any (a: lib.hasSuffix "bash" a) agg.apps);
  };

  # --- Partial User Tests ---

  # Test: User without fullName is NOT created as NixOS user
  smoke-partial-user-not-created = mkSmokeTest {
    name = "test-partial-user";
    myConfig = {
      system.enable = true;
      system.hostname = "test-partial-user";
      # Partial user: has email but no fullName
      users.partialuser = {
        email = "partial@example.com";
      };
      # Full user: has fullName
      users.fulluser = {
        fullName = "Full User";
        description = "Full User";
        email = "full@example.com";
        terminal.enable = true;
      };
    };
    assertions = config:
      # Full user should be created
      config.users.users ? fulluser
      && config.users.users.fulluser.isNormalUser
      # Partial user should NOT be created as NixOS user
      && !(config.users.users ? partialuser);
  };

  # Test: Partial user with mounts still gets filesystem entries
  smoke-partial-user-mounts = mkSmokeTest {
    name = "test-partial-user-mounts";
    myConfig = {
      system.enable = true;
      system.hostname = "test-partial-user-mounts";
      users.mountuser = {
        email = "mount@example.com";
        mounts = [{
          mountPoint = "/mnt/data";
          device = "/dev/sdb1";
          fsType = "ext4";
          options = [ "defaults" ];
          noCheck = false;
        }];
      };
    };
    assertions = config:
      # Mount should be created even without fullName
      config.fileSystems ? "/mnt/data"
      && config.fileSystems."/mnt/data".device == "/dev/sdb1"
      # But user should NOT be created
      && !(config.users.users ? mountuser);
  };

  # --- Display Manager Tests ---

  # Test: Display manager enum accepts valid values
  smoke-display-manager-greetd = mkSmokeTest {
    name = "test-dm-greetd";
    myConfig = {
      system.enable = true;
      system.hostname = "test-dm-greetd";
      environment.enable = true;
      environment.displayManager.type = "greetd";
    };
    assertions = config:
      config.my.environment.displayManager.type == "greetd";
  };

  smoke-display-manager-gdm = mkSmokeTest {
    name = "test-dm-gdm";
    myConfig = {
      system.enable = true;
      system.hostname = "test-dm-gdm";
      environment.enable = true;
      environment.displayManager.type = "gdm";
    };
    assertions = config:
      config.my.environment.displayManager.type == "gdm";
  };

  # --- Network Defense Tests ---

  # Test: Network defense module evaluates with core sub-modules enabled
  smoke-network-defense = mkSmokeTest {
    name = "test-network-defense";
    myConfig = {
      system.enable = true;
      system.hostname = "test-network-defense";
      network.monitoring = {
        enable = true;
        interface = "eth0";
        linkMonitor.enable = true;
        addrwatch.enable = true;
        pcap = {
          enable = true;
          rotateSeconds = 1800;
          maxFiles = 48;
        };
        tshark.enable = true;
        p0f.enable = true;
        aide.enable = true;
        dns.enable = true;
      };
    };
    assertions = config:
      let
        cfg = config.my.network.monitoring;
      in
      cfg.enable
      && cfg.interface == "eth0"
      && cfg.linkMonitor.enable
      && cfg.addrwatch.enable
      && cfg.pcap.enable
      && cfg.pcap.rotateSeconds == 1800
      && cfg.pcap.maxFiles == 48
      && cfg.p0f.enable
      && cfg.aide.enable
      && cfg.dns.enable
      # Services should be defined
      && config.systemd.services ? network-link-monitor
      && config.systemd.services ? network-addrwatch
      && config.systemd.services ? network-pcap
      && config.systemd.services ? network-p0f
      && config.systemd.timers ? aide-check
      && config.services.blocky.enable;
  };

  # Test: Network defense disabled produces no services
  smoke-network-defense-disabled = mkSmokeTest {
    name = "test-network-defense-disabled";
    myConfig = {
      system.enable = true;
      system.hostname = "test-network-defense-disabled";
    };
    assertions = config:
      !(config.systemd.services ? network-link-monitor)
      && !(config.systemd.services ? network-arpwatch)
      && !(config.systemd.services ? network-pcap)
      && !(config.systemd.services ? network-zeek)
      && !(config.systemd.services ? network-p0f);
  };

  # --- Feature Override Tests ---

  # Test: User can override opinionated defaults
  smoke-override-defaults = mkSmokeTest {
    name = "test-override-defaults";
    myConfig = {
      system.enable = true;
      system.hostname = "test-override-defaults";
      users.testuser = {
        fullName = "Test User";
        description = "Test User";
        email = "test@example.com";
        terminal.enable = true;
        # Override: disable bash (opinionated default)
        apps.terminal.shells.bash.enable = false;
        # Override: disable bat (opinionated default)
        apps.terminal.viewers.bat.enable = false;
      };
    };
    assertions = config:
      # Overrides should take effect
      !config.my.users.testuser.apps.terminal.shells.bash.enable
      && !config.my.users.testuser.apps.terminal.viewers.bat.enable
      # But other terminal defaults should still be on
      && config.my.users.testuser.apps.terminal.prompts.starship.enable;
  };

  # --- Empty / Minimal Config Tests ---

  # Test: No users configured is valid
  smoke-no-users = mkSmokeTest {
    name = "test-no-users";
    myConfig = {
      system.enable = true;
      system.hostname = "test-no-users";
    };
    assertions = config:
      config.networking.hostName == "test-no-users"
      && !config.my.graphical.enable;
  };

  # Test: User with no features enabled still evaluates and gets app-level defaults
  smoke-user-no-features = mkSmokeTest {
    name = "test-user-no-features";
    myConfig = {
      system.enable = true;
      system.hostname = "test-user-no-features";
      users.bareuser = {
        fullName = "Bare User";
        description = "Bare User";
        email = "bare@example.com";
      };
    };
    assertions = config:
      config.users.users.bareuser.isNormalUser
      # App-level defaults (mkAppOption default=true) still apply
      # but feature-gated opinionated defaults (from mynixos.nix) do NOT
      && !config.my.users.bareuser.apps.graphical.browsers.brave.enable
      && !config.my.users.bareuser.apps.dev.tools.direnv.enable;
  };

  # --- Performance Module Tests ---

  # Test: Performance with custom zram
  smoke-performance-zram = mkSmokeTest {
    name = "test-performance-zram";
    myConfig = {
      system.enable = true;
      system.hostname = "test-performance-zram";
      performance.enable = true;
      performance.zramPercent = 25;
    };
    assertions = config:
      config.my.performance.enable
      && config.my.performance.zramPercent == 25;
  };

  # --- Preset Tests ---

  # Test: Workstation preset enables expected system features
  smoke-preset-workstation = mkSmokeTest {
    name = "test-preset-workstation";
    myConfig = {
      system.hostname = "test-preset-workstation";
      presets.workstation.enable = true;
    };
    assertions = config:
      config.my.system.enable
      && config.my.environment.enable
      && config.my.performance.enable;
  };
}
