{ config, lib, pkgs, ... }:

{
  # UEFI boot configuration for Lenovo Legion Pro 7 16IRX8H

  # Bootloader - GRUB for EFI (overrides systemd-boot from common modules)
  boot.loader.grub = {
    enable = true;
    device = "nodev";
    efiSupport = true;
    # Conservative default for laptops - can be overridden by system config
    configurationLimit = lib.mkOverride 1500 10;
  };
  boot.loader.systemd-boot.enable = lib.mkForce false;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.timeout = lib.mkDefault 2; # Fast boot

  # Use latest kernel
  boot.kernelPackages = pkgs.linuxPackages_latest;

  # Hardware detected kernel modules
  boot.initrd.availableKernelModules = [
    "xhci_pci"
    "nvme"
    "thunderbolt"
    "usbhid"
    "usb_storage"
    "sd_mod"
  ];

  boot.extraModulePackages = [ ];

  # Mask audit-rules service (cosmetic fix for this hardware)
  # Rules are loaded early via kernel cmdline
  systemd.services.audit-rules.enable = false;
}
