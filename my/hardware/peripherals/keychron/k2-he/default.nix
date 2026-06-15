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

    # The K2 HE IS registered as a QMK OpenRGB device -- via the vogix path:
    # my.theming.vogix sets vogix.hardware.keychron-k2-he.enable, whose module
    # adds it to vogix.openrgb.qmkDevices and writes it into /var/lib/OpenRGB.
    # The my.theming.openrgb line below is the legacy native path, kept
    # commented so the same device isn't registered twice.
    #
    # History: a 2026-04-14 note here disabled registration because OpenRGB
    # managing the K2 HE made the keyboard's Genesys Logic USB hub cycle
    # (disconnect/reconnect every ~4-10 min, dragging the Logitech receiver
    # and YubiKey offline with it). Root cause was traced to the K2 HE
    # firmware: its OpenRGB command handler was never compiled in (a QMK
    # build-wiring bug), so the keyboard never answered the protocol and
    # OpenRGB kept re-probing/resetting the device. Fixed 2026-06-14 in
    # QMK PR Keychron/qmk_firmware#476; OpenRGB has since enumerated and
    # managed the keyboard with no hub cycling. Revert to disabled if it recurs.
    # my.theming.openrgb.qmkDevices = mkIf cfg.enable [{ name = "Keychron K2 HE"; vid = "0x3434"; pid = "0x0E20"; }];
  };
}
