{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.my.hardware.cpu;
in
{
  config = mkIf (cfg == "intel") {
    # Intel CPU configuration
    boot.kernelModules = [ "kvm-intel" ];

    # CPU microcode updates
    hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
  };
}
