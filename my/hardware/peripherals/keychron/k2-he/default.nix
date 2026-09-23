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

    # The K2 HE is a QMK OpenRGB device, which OpenRGB lists only when it is
    # registered as one. vogix registers it whenever vogix's K2 HE module is
    # on (my.theming.vogix with a machine owner); otherwise it is registered
    # here, so it is registered exactly once.
    #
    # The keyboard answers OpenRGB's protocol only with firmware carrying
    # Keychron/qmk_firmware#476. Without it OpenRGB keeps re-probing and
    # resetting the keyboard, and its Genesys Logic USB hub disconnects every
    # few minutes, taking the devices behind it (the Logitech receiver, the
    # YubiKey) with it.
    my.theming.openrgb.qmkDevices = mkIf (cfg.enable && !config.vogix.hardware.keychron-k2-he.enable) [
      { name = "Keychron K2 HE"; vid = "0x3434"; pid = "0x0E20"; }
    ];
  };
}
