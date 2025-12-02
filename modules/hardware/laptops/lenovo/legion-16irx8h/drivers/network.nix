{ config, lib, pkgs, ... }:

{
  # Network hardware configuration for Lenovo Legion Pro 7 16IRX8H
  # Intel WiFi 6E + Ethernet

  networking.useDHCP = lib.mkDefault true;
  networking.wireless.enable = false; # Using NetworkManager

  # Thunderbolt 4 support
  services.hardware.bolt.enable = true;
}
