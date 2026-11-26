{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.my.hardware.peripherals.apple.dfu;

  udevRules = pkgs.writeTextFile {
    name = "apple-dfu-udev-rules";
    destination = "/lib/udev/rules.d/60-apple-dfu.rules";
    text = ''
      # Apple iOS/iPadOS devices in WTF, DFU, or Recovery mode (libirecovery)
      ACTION=="add", SUBSYSTEM=="usb", ATTR{idVendor}=="05ac", ATTR{idProduct}=="122[27]|128[0-3]", TAG+="uaccess"
      # checkra1n / pongoOS DFU mode
      ACTION=="add", SUBSYSTEM=="usb", ATTR{idVendor}=="05ac", ATTR{idProduct}=="1338", TAG+="uaccess"
    '';
  };
in
{
  config = {
    # Only when device is enabled
    services.udev.packages = mkIf (cfg.enable && cfg.udev) [ udevRules ];
  };
}
