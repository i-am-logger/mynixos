{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.my.hardware.storage.usb;
in
{
  options.my.hardware.storage.usb = {
    enable = mkEnableOption "USB storage support (USB drives and SD cards)";
  };

  config = mkIf cfg.enable {
    # USB storage and SD card reader kernel modules
    boot.initrd.availableKernelModules = [
      "usb_storage"  # USB mass storage devices
      "sd_mod"       # SD/MMC card readers
    ];
  };
}
