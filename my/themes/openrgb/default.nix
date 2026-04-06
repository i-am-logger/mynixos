{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.my.themes.openrgb;
  hwCpu = config.my.hardware.cpu;

  qmkDevicesJson = if cfg.qmkDevices != [ ] then {
    devices = map
      (dev: {
        name = dev.name;
        usb_vid = dev.vid;
        usb_pid = dev.pid;
      })
      cfg.qmkDevices;
  } else null;

  serverConfig = pkgs.writeText "openrgb-server-config.json" (builtins.toJSON {
    QMKOpenRGBDevices = qmkDevicesJson;
  });
in
{
  config = mkIf cfg.enable {
    services.hardware.openrgb = {
      enable = true;
      # Set motherboard type from my.hardware.cpu for proper i2c/SMBus support
      motherboard = mkIf (hwCpu != null) (mkDefault hwCpu);
    };

    # Merge QMK device list into server config before starting
    systemd.services.openrgb = mkIf (cfg.qmkDevices != [ ]) {
      serviceConfig.ExecStartPre = "${pkgs.writeShellScript "openrgb-qmk-setup" ''
        CONFIG="/var/lib/OpenRGB/OpenRGB.json"
        if [ -f "$CONFIG" ]; then
          ${pkgs.jq}/bin/jq --argjson qmk '${builtins.toJSON qmkDevicesJson}' '.QMKOpenRGBDevices = $qmk' "$CONFIG" > "$CONFIG.tmp" && mv "$CONFIG.tmp" "$CONFIG"
        else
          cp ${serverConfig} "$CONFIG"
        fi
      ''}";
    };
  };
}
