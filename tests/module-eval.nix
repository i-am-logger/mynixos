{ lib
, nixpkgs
, system
, self
, inputs
}:

let
  pkgs = nixpkgs.legacyPackages.${system};

  # Helper: evaluate a NixOS system with the mynixos module and given config
  #
  # We pass pkgs via specialArgs to break the infinite recursion that occurs
  # when hardware/theme modules set nixpkgs.* options inside mkIf conditions.
  # Without this, evaluating pkgs requires config, which requires evaluating
  # the mkIf conditions, which requires pkgs again.
  evalTest = name: testConfig:
    let
      eval = lib.nixosSystem {
        specialArgs = {
          inherit inputs self pkgs;
          inherit (inputs) disko impermanence stylix vogix lanzaboote sops-nix;
        };

        modules = [
          self.nixosModules.default
          inputs.home-manager.nixosModules.home-manager
          inputs.sops-nix.nixosModules.sops
          {
            # Minimal base config required for NixOS evaluation
            boot.loader.grub.devices = [ "nodev" ];
            fileSystems."/" = {
              device = "tmpfs";
              fsType = "tmpfs";
            };
            system.stateVersion = "24.11";
            nixpkgs.hostPlatform = system;
          }
          testConfig
        ];
      };

      # Force evaluation by referencing config values
      evaluatedHostname = eval.config.networking.hostName;
    in
    pkgs.runCommand "module-eval-${name}" { } ''
      # If we got here, evaluation succeeded (it happens at nix eval time)
      echo "Evaluated config for host: ${evaluatedHostname}"
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
  user-features = evalTest "user-features" {
    networking.hostName = "test-user-features";
    my.users.testuser = {
      fullName = "Test User";
      features = {
        terminal = true;
        dev = true;
      };
    };
    home-manager = {
      useUserPackages = true;
      backupFileExtension = "backup";
      users.testuser = { };
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
}
