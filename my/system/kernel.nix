{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.my.system;
in
{
  config = mkMerge [
    # Hostname configuration (backwards compatible)
    {
      networking.hostName = mkDefault (
        if cfg.hostname != null then cfg.hostname
        else if config.my.hostname != null then config.my.hostname
        else throw "Either my.system.hostname or my.hostname must be set"
      );
    }

    # Kernel configuration
    # Default: linuxPackages_latest (mynixos opinionated default)
    # Hardware modules may override with mkDefault
    # Users can override by setting my.system.kernel = pkgs.linuxPackages_X_XX
    {
      boot.kernelPackages = mkDefault (
        if cfg.kernel != null
        then cfg.kernel
        else pkgs.linuxPackages_latest # mynixos default
      );
    }

    # Architecture configuration (auto-detected from hardware, can be overridden)
    (mkIf (cfg.architecture != null) {
      nixpkgs.hostPlatform = mkDefault cfg.architecture;
    })
  ];
}
