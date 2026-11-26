# iPhone/iPad over USB in normal mode (my.hardware.peripherals.apple.ios).
#
# usbmuxd multiplexes the device's USB connection for every libimobiledevice
# client; nixpkgs' module also installs its udev rules. A device in DFU or
# Recovery mode is ../dfu's.
{ config, lib, ... }:

{
  config = lib.mkIf config.my.hardware.peripherals.apple.ios.enable {
    services.usbmuxd.enable = true;
  };
}
