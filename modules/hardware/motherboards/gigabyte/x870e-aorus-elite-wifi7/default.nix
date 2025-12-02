{ config, lib, pkgs, modulesPath, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ./drivers/uefi-boot.nix # Motherboard-specific kernel config
  ];

  # Hardware specification for this motherboard
  my.hardware = {
    cpu = "amd";
    gpu = "amd";
    bluetooth.enable = true;
    audio.enable = true;
  };

  # Platform architecture
  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
