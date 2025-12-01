{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.my.hardware.bluetooth;
in
{
  config = mkIf (cfg.enable) {
    # Realtek Bluetooth configuration
    hardware.bluetooth = {
      enable = true;
      powerOnBoot = lib.mkDefault true;
    };
    services.blueman.enable = true;
  };
}
