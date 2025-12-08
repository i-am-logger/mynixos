{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.my.hardware.storage.nvme;
in
{
  options.my.hardware.storage.nvme = {
    enable = mkEnableOption "NVMe storage support";
  };

  config = mkIf cfg.enable {
    # NVMe kernel module for boot
    boot.initrd.availableKernelModules = [ "nvme" ];
  };
}
