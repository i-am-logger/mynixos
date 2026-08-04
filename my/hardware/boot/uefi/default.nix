{ config, lib, ... }:

with lib;

let
  cfg = config.my.boot;
  # Lanzaboote replaces systemd-boot, so the bootloader choice follows the live
  # secure-boot flag. There used to be a second `my.boot.secure` switch here that
  # nothing set, and which read `false` on a host with secure boot ON.
  secure = config.my.security.secureBoot.enable;
in
{
  config = mkMerge [
    (mkIf cfg.uefi {
      boot.loader.efi.canTouchEfiVariables = true;
    })

    (mkIf (cfg.uefi && !secure) {
      boot.loader.systemd-boot.enable = true;
    })

    (mkIf secure {
      boot.loader.systemd-boot.enable = mkForce false;
    })
  ];
}
