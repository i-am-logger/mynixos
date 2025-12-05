{ config, lib, pkgs, ... }:

{
  # UEFI boot configuration for Gigabyte X870E motherboard

  # Bootloader - disabled for lanzaboote (Secure Boot)
  boot.loader.systemd-boot.enable = lib.mkForce false;
  boot.loader.efi.canTouchEfiVariables = lib.mkDefault true;

  # Use latest kernel (can be overridden)
  boot.kernelPackages = lib.mkDefault pkgs.linuxPackages_latest;

  # Hardware detected kernel modules
  boot.initrd.availableKernelModules = lib.mkDefault [
    "nvme"
    "ahci"
    "xhci_pci"
    "thunderbolt"
    "usb_storage"
    "usbhid"
    "sd_mod"
  ];

  boot.extraModulePackages = lib.mkDefault [ ];
}
