# Logi Bolt receiver (046d:c548). Its paired mouse or keyboard already works
# as plain HID input; this adds what Logitech's Options+ does elsewhere:
# pairing, battery levels and button/wheel settings, through Solaar.
{ config, lib, ... }:

let
  cfg = config.my.hardware.peripherals.logitech.bolt;
in
{
  config = lib.mkIf cfg.enable {
    # udev rules (hidraw access for non-root) and ltunify.
    hardware.logitech.wireless.enable = true;

    programs.solaar = {
      enable = true;
      # Starts with graphical-session.target, hidden in the tray.
      userService = lib.mkIf cfg.tray {
        enable = true;
        window = "hide";
      };
    };
  };
}
