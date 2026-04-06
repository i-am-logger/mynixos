{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.my.hardware.peripherals.keychron.k2-he;

  udevRules = pkgs.writeTextFile {
    name = "keychron-k2-he-udev-rules";
    destination = "/lib/udev/rules.d/60-keychron.rules";
    text = ''
      # Keychron K2 HE - USB HID access
      SUBSYSTEMS=="usb|hidraw", ATTRS{idVendor}=="3434", ATTRS{idProduct}=="0e20", TAG+="uaccess"
      # STM32 DFU bootloader (firmware flashing)
      SUBSYSTEMS=="usb", ATTRS{idVendor}=="0483", ATTRS{idProduct}=="df11", TAG+="uaccess"
    '';
  };
in
{
  config = {
    # Master switch propagates to device udev via mkDefault
    my.hardware.peripherals.keychron.k2-he.udev = mkDefault config.my.system.udev.enable;

    # Only when device is enabled
    services.udev.packages = mkIf (cfg.enable && cfg.udev) [ udevRules ];

    # Register as QMK OpenRGB device
    my.theming.openrgb.qmkDevices = mkIf cfg.enable [{ name = "Keychron K2 HE"; vid = "0x3434"; pid = "0x0E20"; }];
  };
}
