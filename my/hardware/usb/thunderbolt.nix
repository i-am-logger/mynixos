{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.my.hardware.usb.thunderbolt;
in
{
  options.my.hardware.usb.thunderbolt = {
    enable = mkEnableOption "Thunderbolt support";
  };

  config = mkIf cfg.enable {
    # Thunderbolt kernel module for boot
    boot.initrd.availableKernelModules = [ "thunderbolt" ];

    # Thunderbolt daemon for device authorization
    services.hardware.bolt.enable = mkDefault true;
  };
}
