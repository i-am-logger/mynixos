{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.my.hardware.cpu;
  amdCfg = config.my.hardware.cpu.amd;
in
{
  options.my.hardware.cpu.amd = {
    microcode = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Enable AMD CPU microcode updates";
      };
    };

    virtualization = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Enable KVM virtualization support (kvm-amd)";
      };
    };
  };

  config = mkIf (cfg == "amd") {
    # KVM virtualization support
    boot.kernelModules = mkIf amdCfg.virtualization.enable [ "kvm-amd" ];

    # CPU microcode updates
    hardware.cpu.amd.updateMicrocode = mkIf amdCfg.microcode.enable (
      mkDefault config.hardware.enableRedistributableFirmware
    );
  };
}
