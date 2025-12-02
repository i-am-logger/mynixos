{ config, lib, pkgs, ... }:

{
  # UEFI boot configuration for Gigabyte X870E motherboard

  # Bootloader - disabled for lanzaboote (Secure Boot)
  boot.loader.systemd-boot.enable = lib.mkForce false;
  boot.loader.efi.canTouchEfiVariables = true;

  # Use latest kernel
  boot.kernelPackages = pkgs.linuxPackages_latest;

  # Hardware detected kernel modules
  boot.initrd.availableKernelModules = [
    "nvme"
    "ahci"
    "xhci_pci"
    "thunderbolt"
    "usb_storage"
    "usbhid"
    "sd_mod"
  ];

  boot.extraModulePackages = [ ];
}
