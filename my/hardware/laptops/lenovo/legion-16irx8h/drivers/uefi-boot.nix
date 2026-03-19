{ lib, pkgs, ... }:

{
  # UEFI boot configuration for Lenovo Legion Pro 7 16IRX8H
  # Kernel modules are now handled by hardware options:
  # - my.hardware.storage.nvme (nvme)
  # - my.hardware.storage.usb (usb_storage, sd_mod)
  # - my.hardware.usb.xhci (xhci_pci)
  # - my.hardware.usb.thunderbolt (thunderbolt)
  # - my.hardware.usb.hid (usbhid)
  # These are enabled via laptop options in default.nix

  # Bootloader - GRUB for EFI (overrides systemd-boot from common modules)
  boot = {
    loader = {
      grub = {
        enable = lib.mkDefault true;
        device = lib.mkDefault "nodev";
        efiSupport = lib.mkDefault true;
        # Conservative default for laptops - can be overridden by system config
        configurationLimit = lib.mkOverride 1500 10;
      };
      systemd-boot.enable = lib.mkForce false;
      efi.canTouchEfiVariables = lib.mkDefault true;
      timeout = lib.mkDefault 2; # Fast boot
    };

    # Use latest kernel (can be overridden)
    kernelPackages = lib.mkDefault pkgs.linuxPackages_latest;
  };

  # Audit-rules masking is handled by my.security.auditRules
}
