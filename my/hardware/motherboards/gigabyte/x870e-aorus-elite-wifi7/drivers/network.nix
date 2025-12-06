{ config, lib, pkgs, ... }:

{
  # Network hardware configuration for Gigabyte X870E
  # Intel I225-V Ethernet + WiFi7

  networking.useDHCP = lib.mkDefault true;
  networking.wireless.enable = false; # Using NetworkManager for WiFi

  # Thunderbolt 4 support
  services.hardware.bolt.enable = true;
}
