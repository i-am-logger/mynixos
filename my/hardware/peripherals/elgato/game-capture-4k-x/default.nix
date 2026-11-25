# Elgato Game Capture 4K X (0fd9:009b).
#
# The video is plain UVC (uvcvideo; YUYV, NV12, P010 for 10-bit HDR, ...).
# Its vendor controls -- HDR tone mapping, EDID mode -- go over the same USB
# device through libusb, which needs the usbfs node read-write. That node is
# root:root 0664 by default, so tools like elgato4k-linux only ran with sudo;
# uaccess hands it to the logged-in seat user instead.
{ config, lib, pkgs, ... }:

let
  cfg = config.my.hardware.peripherals.elgato.game-capture-4k-x;

  udevRules = pkgs.writeTextFile {
    name = "elgato-4k-x-udev-rules";
    destination = "/lib/udev/rules.d/70-elgato-4k-x.rules";
    text = ''
      # Elgato Game Capture 4K X: vendor control over usbfs for the seat user.
      SUBSYSTEM=="usb", ATTR{idVendor}=="0fd9", ATTR{idProduct}=="009b", TAG+="uaccess"
    '';
  };
in
{
  config = lib.mkIf cfg.enable {
    services.udev.packages = [ udevRules ];
  };
}
