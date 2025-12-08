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
      powerOnBoot = false; # Don't power on by default to save battery
      settings = {
        General = {
          Enable = "Source,Sink,Media,Socket";
          ControllerMode = "dual";
        };
      };
    };

    services.blueman.enable = true;

    # Restart bluetooth service on failure
    systemd.services.bluetooth = {
      serviceConfig = {
        Restart = "on-failure";
        RestartSec = "5s";
      };
    };

    # Persistence configuration
    my.system.persistence.features = {
      systemDirectories = [
        "/var/lib/bluetooth"
      ];
    };
  };
}
