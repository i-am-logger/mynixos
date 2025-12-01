{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.my.hardware.cpu;
in
{
  config = mkIf (cfg == "amd") {
    # AMD CPU configuration
    boot.kernelModules = [ "kvm-amd" ];

    # CPU microcode updates
    hardware.cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
  };
}
