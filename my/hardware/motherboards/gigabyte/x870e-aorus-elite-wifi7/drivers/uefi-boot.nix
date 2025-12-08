{
  config,
  lib,
  pkgs,
  ...
}:

{
  # UEFI boot configuration for Gigabyte X870E motherboard
  # Kernel modules are now handled by hardware options:
  # - my.hardware.storage.nvme (nvme)
  # - my.hardware.storage.sata (ahci)
  # - my.hardware.storage.usb (usb_storage, sd_mod)
  # - my.hardware.usb.xhci (xhci_pci)
  # - my.hardware.usb.thunderbolt (thunderbolt)
  # - my.hardware.usb.hid (usbhid)
  # These are enabled via motherboard options in default.nix

  # Bootloader - disabled for lanzaboote (Secure Boot)
  boot.loader.systemd-boot.enable = lib.mkForce false;
  boot.loader.efi.canTouchEfiVariables = lib.mkDefault true;
}
