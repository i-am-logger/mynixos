{ config, lib, pkgs, ... }:

let
  # Under Secure Boot, lanzaboote (my.security.secureBoot) owns the ESP and sets
  # boot.loader.grub.enable = false. Enabling GRUB unconditionally here ties with
  # that at equal priority -- a module-system conflict a host could only resolve
  # with its own mkForce. Gate GRUB on !secureBoot instead, and let lanzaboote
  # take the bootloader when it is on.
  secure = config.my.security.secureBoot.enable;
in
{
  # UEFI boot configuration for Lenovo Legion Pro 7 16IRX8H
  # Kernel modules are now handled by hardware options:
  # - my.hardware.storage.nvme (nvme)
  # - my.hardware.storage.usb (usb_storage, sd_mod)
  # - my.hardware.usb.xhci (xhci_pci)
  # - my.hardware.usb.thunderbolt (thunderbolt)
  # - my.hardware.usb.hid (usbhid)
  # These are enabled via laptop options in default.nix

  # Bootloader - GRUB for EFI when Secure Boot is off (overrides systemd-boot
  # from common modules); lanzaboote takes over when secureBoot is on.
  boot = {
    loader = {
      grub = lib.mkIf (!secure) {
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
