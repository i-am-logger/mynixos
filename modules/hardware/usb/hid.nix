{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.my.hardware.usb.hid;
in
{
  options.my.hardware.usb.hid = {
    enable = mkEnableOption "USB HID (Human Interface Device) support for keyboards, mice, etc.";
  };

  config = mkIf cfg.enable {
    # USB HID kernel module for input devices
    boot.initrd.availableKernelModules = [ "usbhid" ];
  };
}
