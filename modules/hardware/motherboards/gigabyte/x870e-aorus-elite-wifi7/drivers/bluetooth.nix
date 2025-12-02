{ config, lib, pkgs, ... }:

{
  # Bluetooth hardware - disabled
  # Gigabyte X870E has Bluetooth capability but user prefers it disabled

  hardware.bluetooth.enable = false;
}
