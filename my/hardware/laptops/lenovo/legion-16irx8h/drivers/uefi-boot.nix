{ config, lib, pkgs, ... }:

{
  # UEFI boot configuration for Lenovo Legion Pro 7 16IRX8H

  # Bootloader - GRUB for EFI (overrides systemd-boot from common modules)
  boot.loader.grub = {
    enable = lib.mkDefault true;
    device = lib.mkDefault "nodev";
    efiSupport = lib.mkDefault true;
    # Conservative default for laptops - can be overridden by system config
    configurationLimit = lib.mkOverride 1500 10;
  };
  boot.loader.systemd-boot.enable = lib.mkForce false;
  boot.loader.efi.canTouchEfiVariables = lib.mkDefault true;
  boot.loader.timeout = lib.mkDefault 2; # Fast boot

  # Use latest kernel (can be overridden)
  boot.kernelPackages = lib.mkDefault pkgs.linuxPackages_latest;

  # Hardware detected kernel modules
  boot.initrd.availableKernelModules = lib.mkDefault [
    "xhci_pci"
    "nvme"
    "thunderbolt"
    "usbhid"
    "usb_storage"
    "sd_mod"
  ];

  boot.extraModulePackages = lib.mkDefault [ ];

  # Mask audit-rules service (cosmetic fix for this hardware)
  # Rules are loaded early via kernel cmdline
  systemd.services.audit-rules.enable = lib.mkDefault false;
}
