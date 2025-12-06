{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.my.hardware.storage.sata;
in
{
  options.my.hardware.storage.sata = {
    enable = mkEnableOption "SATA/AHCI storage support";
  };

  config = mkIf cfg.enable {
    # SATA/AHCI kernel module for boot
    boot.initrd.availableKernelModules = [ "ahci" ];
  };
}
