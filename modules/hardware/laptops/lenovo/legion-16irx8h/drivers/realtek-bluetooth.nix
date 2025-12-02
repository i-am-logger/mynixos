{ config, lib, pkgs, ... }:

{
  # Realtek Bluetooth chipset driver
  # Lenovo Legion Pro 7 16IRX8H uses Realtek Bluetooth

  # Note: Bluetooth is currently disabled in system config
  # Uncomment below to enable Bluetooth hardware support
  # hardware.bluetooth.enable = true;
  # hardware.bluetooth.powerOnBoot = false;  # Don't auto-power on
}
