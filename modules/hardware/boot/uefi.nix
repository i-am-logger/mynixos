{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.my.hardware.boot;
in
{
  options.my.hardware.boot = {
    secure = mkEnableOption "Secure Boot with Lanzaboote";

    uefi = mkOption {
      type = types.bool;
      default = true;
      description = "Enable UEFI boot";
    };
  };

  config = mkMerge [
    # Common UEFI settings
    (mkIf cfg.uefi {
      boot.loader.efi.canTouchEfiVariables = true;
    })

    # Standard systemd-boot (when secure boot is disabled)
    (mkIf (cfg.uefi && !cfg.secure) {
      boot.loader.systemd-boot.enable = true;
    })

    # Secure boot mode (disable systemd-boot for Lanzaboote)
    (mkIf cfg.secure {
      boot.loader.systemd-boot.enable = mkForce false;
    })
  ];
}
