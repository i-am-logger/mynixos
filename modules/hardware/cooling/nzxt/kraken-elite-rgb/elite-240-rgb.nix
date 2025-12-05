{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.hardware.cooling.nzxt.kraken-elite-240-rgb;
in
{
  options.hardware.cooling.nzxt.kraken-elite-240-rgb = {
    enable = mkEnableOption "NZXT Kraken Elite 240 RGB (240mm AIO with 2.72\" LCD)";

    lcd = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Enable LCD screen support (always true for Elite RGB models)";
      };

      brightness = mkOption {
        type = types.int;
        default = 100;
        description = "LCD screen brightness (0-100)";
      };
    };

    rgb = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Enable RGB ring around LCD screen";
      };
    };

    liquidctl = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Install liquidctl CLI tool for manual control (fan curves, pump speed, RGB, LCD)";
      };

      autoInitialize = mkOption {
        type = types.bool;
        default = false;
        description = "Automatically run 'liquidctl initialize' on boot to detect and initialize the device";
      };
    };

    monitoring = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Install lm_sensors for temperature and fan speed monitoring";
      };
    };
  };

  config = mkIf cfg.enable {
    # Load kernel module for NZXT Kraken hardware control (built into kernel since Linux 5.13)
    boot.kernelModules = [ "nzxt_kraken3" ];

    # LCD support is always enabled for Elite RGB models
    boot.extraModprobeConfig = mkIf (!cfg.lcd.enable) ''
      # Note: Elite RGB models have LCD screens - disabling may cause issues
      options nzxt_kraken3 disable_lcd=1
    '';

    # Install userspace control tools
    environment.systemPackages =
      (optionals cfg.liquidctl.enable [ pkgs.liquidctl ])
      ++ (optionals cfg.monitoring.enable [ pkgs.lm_sensors ]);

    # udev rules for liquidctl device access
    services.udev.packages = mkIf cfg.liquidctl.enable [ pkgs.liquidctl ];

    # Systemd service to automatically initialize liquidctl on boot
    systemd.services.liquidctl-kraken-elite = mkIf (cfg.liquidctl.enable && cfg.liquidctl.autoInitialize) {
      description = "NZXT Kraken Elite 240 RGB liquidctl initialization";
      wantedBy = [ "multi-user.target" ];
      after = [ "systemd-udev-settle.service" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = "${pkgs.liquidctl}/bin/liquidctl initialize";
      };
    };
  };
}
