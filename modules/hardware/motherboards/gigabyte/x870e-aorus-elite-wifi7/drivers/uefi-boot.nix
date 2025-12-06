{
  config,
  lib,
  pkgs,
  ...
}:

{
  # TODO: these shoudl move to the right section in hardware or system
  # UEFI boot configuration for Gigabyte X870E motherboard

  # Bootloader - disabled for lanzaboote (Secure Boot)
  boot.loader.systemd-boot.enable = lib.mkForce false;
  boot.loader.efi.canTouchEfiVariables = lib.mkDefault true;

  # Kernel configuration moved to my.system.kernel in mynixos system module
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
