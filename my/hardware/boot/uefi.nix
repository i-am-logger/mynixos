{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.my.boot;
in
{
  # Options are defined in flake.nix under my.boot namespace
  # This module only provides the implementation

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
