{ config, lib, pkgs, ... }:

{
  # Intel Core i9-13900HX CPU configuration

  # Intel KVM support
  boot.kernelModules = [ "kvm-intel" ];

  # CPU microcode updates
  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
}
