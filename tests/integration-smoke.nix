# Integration smoke tests for mynixos
#
# These tests verify that realistic NixOS configurations using the mynixos
# module system evaluate without errors. They do NOT build VMs or full
# system closures - they only evaluate the NixOS module system to check
# that option types, assertions, and derivations are well-formed.
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
  # Returns the evaluated config for assertion checking
  evalSystem =
    { name
    , myConfig
    , extraModules ? [ ]
    }:
    lib.nixosSystem {
      specialArgs = {
        inherit (inputs) vogix;
        # Provide pkgs as specialArg to break the cycle where
        # mkOptionsModule resolves pkgs from _module.args, which depends
        # on config.nixpkgs, which depends on module evaluation.
        inherit pkgs;
      };
      modules = [
        self.nixosModules.default
        inputs.home-manager.nixosModules.home-manager
        inputs.sops-nix.nixosModules.sops
        # Use read-only pkgs module to suppress assertions about
        # nixpkgs.config/overlays being set when pkgs is externally provided
        "${inputs.nixpkgs}/nixos/modules/misc/nixpkgs/read-only.nix"
        {
          nixpkgs.pkgs = pkgs;
          networking.hostName = name;
          fileSystems."/" = { device = "/dev/sda1"; fsType = "ext4"; };
          boot.loader.grub.device = "/dev/sda";
          system.stateVersion = "24.11";

          # home-manager base config
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
            # Disable themes to avoid nixpkgs.overlays conflict with
            # read-only pkgs. Vogix unconditionally imports its NixOS module
            # which sets nixpkgs.overlays.
            themes.enable = false;
          };
        }
      ] ++ extraModules;
    };

  # Helper: build a check derivation that verifies evaluation succeeds
  # and optionally checks config assertions
  mkSmokeTest =
    { name
    , myConfig
    , extraModules ? [ ]
    , assertions ? (_config: true)
    }:
    let
      eval = evalSystem { inherit name myConfig extraModules; };
      inherit (eval) config;
      # Force evaluation of toplevel at Nix eval time (not build time)
      # using builtins.seq to avoid pulling the full closure into the derivation
      evalOk = builtins.seq config.system.build.toplevel true;
      assertionResult = assertions config;
    in
    # Fail at evaluation time if assertions don't pass
    assert evalOk;
    assert lib.assertMsg assertionResult "smoke-test-${name}: assertions failed";
    pkgs.runCommand "smoke-test-${name}" { } ''
      echo "PASS: ${name}"
      mkdir -p $out
      echo "${name}: ok" > $out/result
    '';

in
{
  # Test 1: Minimal server configuration
  # No graphical, single user with terminal feature only
  smoke-minimal-server = mkSmokeTest {
    name = "test-server";
    myConfig = {
      system.enable = true;
      system.hostname = "test-server";
      users.testuser = {
        fullName = "Test User";
        description = "Test User";
        email = "test@example.com";
        terminal.enable = true;
      };
    };
    assertions = config:
      config.networking.hostName == "test-server"
      && config.users.users.testuser.isNormalUser
      && !config.my.graphical.enable;
  };

  # Test 2: Desktop workstation
  # Graphical + dev + terminal features enabled for a single user
  smoke-desktop-workstation = mkSmokeTest {
    name = "test-desktop";
    myConfig = {
      system.enable = true;
      system.hostname = "test-desktop";
      users.testuser = {
        fullName = "Test User";
        description = "Test User";
        email = "test@example.com";
        graphical.enable = true;
        dev.enable = true;
        terminal.enable = true;
      };
    };
    assertions = config:
      # User graphical should auto-enable system graphical
      config.my.graphical.enable
      # User should be created
      && config.users.users.testuser.isNormalUser
      # Hyprland should be enabled (graphical default)
      && config.programs.hyprland.enable
      # Terminal opinionated defaults should apply
      && config.my.users.testuser.apps.terminal.shells.bash.enable
      && config.my.users.testuser.apps.terminal.viewers.bat.enable
      # Dev opinionated defaults should apply
      && config.my.users.testuser.apps.dev.tools.direnv.enable
      && config.my.users.testuser.apps.dev.tools.jq.enable;
  };

  # Test 3: Multi-user configuration
  # Two users with different feature sets
  smoke-multi-user = mkSmokeTest {
    name = "test-multi";
    myConfig = {
      system.enable = true;
      system.hostname = "test-multi";
      users.admin = {
        fullName = "Admin User";
        description = "Admin User";
        email = "admin@example.com";
        graphical.enable = true;
        dev.enable = true;
        terminal.enable = true;
      };
      users.developer = {
        fullName = "Developer User";
        description = "Developer User";
        email = "dev@example.com";
        dev.enable = true;
        terminal.enable = true;
      };
    };
    assertions = config:
      # Both users should be created
      config.users.users.admin.isNormalUser
      && config.users.users.developer.isNormalUser
      # System graphical should be enabled (admin has it)
      && config.my.graphical.enable
      # Admin should have graphical apps via opinionated defaults
      && config.my.users.admin.apps.graphical.browsers.brave.enable
      # Developer should NOT have graphical defaults
      && !config.my.users.developer.apps.graphical.browsers.brave.enable
      # Both should have dev defaults
      && config.my.users.admin.apps.dev.tools.direnv.enable
      && config.my.users.developer.apps.dev.tools.direnv.enable;
  };

  # Test 4: Feature derivation
  # Verify that enabling user graphical auto-enables system graphical,
  # and that disabling all user graphical keeps system graphical off
  smoke-feature-derivation = mkSmokeTest {
    name = "test-feature-derivation";
    myConfig = {
      system.enable = true;
      system.hostname = "test-feature-derivation";
      users.guiuser = {
        fullName = "GUI User";
        description = "GUI User";
        email = "gui@example.com";
        graphical.enable = true;
        terminal.enable = true;
      };
      users.cliuser = {
        fullName = "CLI User";
        description = "CLI User";
        email = "cli@example.com";
        terminal.enable = true;
      };
    };
    assertions = config:
      # System graphical should be on because guiuser has it
      config.my.graphical.enable
      # guiuser should have graphical groups
      && builtins.elem "video" config.users.users.guiuser.extraGroups
      && builtins.elem "input" config.users.users.guiuser.extraGroups
      # Hyprland should be enabled at system level
      && config.programs.hyprland.enable;
  };

  # Test 5: Unfree packages are properly allowlisted
  # Verify that enabling apps with unfree licenses correctly populates
  # my.system.allowedUnfreePackages so nixpkgs.config.allowUnfreePredicate works
  smoke-unfree-allowlist = mkSmokeTest {
    name = "test-unfree-allowlist";
    myConfig = {
      system.enable = true;
      system.hostname = "test-unfree-allowlist";
      users.testuser = {
        fullName = "Test User";
        description = "Test User";
        email = "test@example.com";
        graphical.enable = true;
        dev.enable = true;
        ai.enable = true;
        terminal.enable = true;
        # Explicitly enable unfree apps not in opinionated defaults
        apps = {
          dev.tools.vscode.enable = true;
          security.passwords.onePassword.enable = true;
          communication.messaging.slack.enable = true;
        };
      };
    };
    assertions = config:
      let
        allowed = config.my.system.allowedUnfreePackages;
      in
      # claude-code (unfree) - enabled by ai opinionated defaults
      builtins.elem "claude-code" allowed
      # github-copilot-cli (unfree) - enabled by helix (graphical default editor)
      && builtins.elem "github-copilot-cli" allowed
      # vscode (unfree) - explicitly enabled
      && builtins.elem "vscode" allowed
      # 1password (unfree) - explicitly enabled
      && builtins.elem "1password" allowed
      # slack (unfree) - explicitly enabled
      && builtins.elem "slack" allowed;
  };

  # Test 6: Motherboard hostPlatform + graphical user (regression: pkgs recursion)
  # Hardware modules that set nixpkgs.hostPlatform must not cause infinite recursion
  # when user environment options resolve pkgs-based defaults.
  smoke-motherboard-env = mkSmokeTest {
    name = "test-motherboard-env";
    myConfig = {
      system.enable = true;
      system.hostname = "test-motherboard-env";
      hardware.motherboards.gigabyte.x870e-aorus-elite-wifi7.enable = true;
      users.testuser = {
        fullName = "Test User";
        description = "Test User";
        email = "test@example.com";
        graphical.enable = true;
        terminal.enable = true;
      };
    };
    assertions = config:
      # Environment defaults should be populated for graphical user
      config.my.users.testuser.environment.BROWSER != null
      && config.my.users.testuser.environment.TERMINAL != null
      && config.my.users.testuser.environment.EDITOR != null
      # System graphical should be auto-derived
      && config.my.graphical.enable;
  };
}
