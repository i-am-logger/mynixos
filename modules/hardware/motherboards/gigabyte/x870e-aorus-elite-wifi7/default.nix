{ config, lib, pkgs, modulesPath, ... }:

let
  cfg = config.my.hardware.motherboards.gigabyte.x870e-aorus-elite-wifi7;
in
{
  imports = [
    ./hardware-configuration.nix
  ];

  config = lib.mkIf cfg.enable (lib.mkMerge [
    # Import motherboard-specific boot configuration
    (import ./drivers/uefi-boot.nix { inherit config lib pkgs; })

    # Additional configuration
    {
      # Hardware specification for this motherboard
      my.hardware = {
        cpu = "amd"; # Hardcoded - this motherboard has AMD CPU
        gpu = "amd"; # Hardcoded - this motherboard has AMD GPU
        bluetooth.enable = lib.mkDefault true; # Can be disabled via my.hardware.bluetooth.enable = false
        audio.enable = lib.mkDefault true; # Can be disabled via my.hardware.audio.enable = false
      };

      # Platform architecture
      nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
    }
  ]);
}
