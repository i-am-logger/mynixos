{ lib
, nixpkgs
, system
, self
, inputs
}:

let
  testLib = import ./lib.nix { inherit lib nixpkgs system self inputs; };
  inherit (testLib) pkgs specialArgs baseModules baseConfig;

  # Helper: evaluate a NixOS system with the mynixos module and given config
  evalTest = name: testConfig:
    let
      eval = lib.nixosSystem {
        inherit specialArgs;
        modules = baseModules ++ [ baseConfig testConfig ];
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
