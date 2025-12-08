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

    # AMD CPU optimizations
    boot.kernelParams = [
      # Ensure SMT (Simultaneous Multithreading) is enabled
      # If you see only 8 cores instead of 16 on a 9950X3D, check BIOS settings:
      # - Advanced > AMD CBS > CPU Common Options > Core/Thread Enablement > SMT Control = Auto/Enabled
      # - Advanced > AMD CBS > CPU Common Options > Core/Thread Enablement > Downcore Control = Disabled
      "smt=on"
    ];
  };
}
