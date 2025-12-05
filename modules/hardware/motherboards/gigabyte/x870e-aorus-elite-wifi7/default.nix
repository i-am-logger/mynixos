{ config, lib, pkgs, modulesPath, ... }:

with lib;

let
  cfg = config.my.hardware.motherboards.gigabyte.x870e-aorus-elite-wifi7;
in
{
  imports = [
    ./hardware-configuration.nix
    ./drivers/uefi-boot.nix # Motherboard-specific kernel config
  ];

  config = mkIf cfg.enable {
    # Hardware specification for this motherboard
    my.hardware = {
      cpu = "amd";
      gpu = "amd";
      bluetooth.enable = true;
      audio.enable = true;
    };

    # Platform architecture
    nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  };
}
