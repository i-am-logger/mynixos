{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.my.hardware.cpu;
in
{
  config = mkIf (cfg == "amd") {
    # KVM virtualization support
    boot.kernelModules = [ "kvm-amd" ];

    # CPU microcode updates
    hardware.cpu.amd.updateMicrocode = mkDefault config.hardware.enableRedistributableFirmware;
  };
}
