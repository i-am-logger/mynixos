{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.my.hardware.gpu;
  amdCfg = config.my.hardware.gpu.amd;
in
{
  options.my.hardware.gpu.amd = {
    # Memory allocation options
    gttsize = mkOption {
      type = types.int;
      default = 8192;
      description = "GTT (Graphics Translation Table) size in MB (default: 8192 = 8GB)";
    };

    vramlimit = mkOption {
      type = types.int;
      default = 4096;
      description = "VRAM limit in MB (default: 4096 = 4GB, adjust based on available system RAM)";
    };

    visVramlimit = mkOption {
      type = types.int;
      default = 512;
      description = "Visible VRAM limit in MB (default: 512MB)";
    };

    moverate = mkOption {
      type = types.int;
      default = 1000;
      description = "Memory movement rate for faster transfers (default: 1000)";
    };

    # Feature flags
    features = {
      deepColor = mkOption {
        type = types.bool;
        default = true;
        description = "Enable HDR support (deep color)";
      };

      displayCore = mkOption {
        type = types.bool;
        default = true;
        description = "Enable Display Core (DC)";
      };

      dcFeatures = mkOption {
        type = types.bool;
        default = true;
        description = "Enable all DC features including DSC (Display Stream Compression)";
      };

      dynamicPowerManagement = mkOption {
        type = types.bool;
        default = true;
        description = "Enable Dynamic Power Management (DPM)";
      };

      displayPortMST = mkOption {
        type = types.bool;
        default = true;
        description = "Enable DisplayPort Multi-Stream Transport (MST)";
      };
    };

    # ROCm support
    rocm = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = "Enable ROCm (Radeon Open Compute) support for GPU computing";
      };
    };

    # Graphics configuration
    graphics = {
      enable32Bit = mkOption {
        type = types.bool;
        default = true;
        description = "Enable 32-bit graphics support for compatibility";
      };
    };
  };

  config = mkIf (cfg == "amd") {
    # Load AMD GPU kernel modules
    boot.initrd.kernelModules = [ "amdgpu" ];
    boot.kernelModules = [ "amdgpu" ];

    # AMD GPU kernel parameters
    boot.kernelParams =
      [
        # Memory allocation
        "amdgpu.gttsize=${toString amdCfg.gttsize}"
        "amdgpu.vramlimit=${toString amdCfg.vramlimit}"
        "amdgpu.vis_vramlimit=${toString amdCfg.visVramlimit}"
        "amdgpu.moverate=${toString amdCfg.moverate}"
      ]
      ++ (optional amdCfg.features.deepColor "amdgpu.deep_color=1")
      ++ (optional amdCfg.features.displayCore "amdgpu.dc=1")
      ++ (optional amdCfg.features.dcFeatures "amdgpu.dc_feature_mask=0xffffffff")
      ++ (optional amdCfg.features.dynamicPowerManagement "amdgpu.dpm=1")
      ++ (optional amdCfg.features.displayPortMST "amdgpu.dp_mst=1");

    # Graphics hardware configuration
    hardware.graphics = {
      enable = true;
      enable32Bit = amdCfg.graphics.enable32Bit;
      extraPackages = with pkgs; [
        libvdpau-va-gl
        libva-utils
      ] ++ optionals amdCfg.rocm.enable [
        rocmPackages.clr.icd
      ];
    };

    # ROCm support configuration
    systemd.tmpfiles.rules = mkIf amdCfg.rocm.enable [
      "L+    /opt/rocm/hip   -    -    -     -    ${pkgs.rocmPackages.clr}"
    ];
  };
}
