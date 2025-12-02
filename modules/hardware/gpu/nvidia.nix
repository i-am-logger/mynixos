{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.my.hardware.gpu;
  cpuVendor = config.my.hardware.cpu;
in
{
  config = mkIf (cfg == "nvidia") {
    # NVIDIA GPU driver configuration with Prime support
    hardware.graphics = {
      enable = true;
      enable32Bit = true;
      extraPackages = with pkgs; [
        intel-media-driver
        libva-vdpau-driver
        libvdpau-va-gl
        vpl-gpu-rt
      ];
    };

    services.xserver.videoDrivers =
      if cpuVendor == "intel"
      then [ "intel" "nvidia" ]
      else [ "nvidia" ];

    nixpkgs.config.cudaSupport = true;

    hardware.nvidia = {
      open = true;
      modesetting.enable = true;
      nvidiaSettings = true;
      nvidiaPersistenced = true;
      dynamicBoost.enable = true;

      # Prime configuration for Intel/NVIDIA hybrid systems
      prime = mkIf (cpuVendor == "intel") {
        offload.enable = mkForce false;
        offload.enableOffloadCmd = mkForce false;
        sync.enable = true;
      };

      package = config.boot.kernelPackages.nvidiaPackages.stable;
    };

    environment.systemPackages = with pkgs; [
      cudatoolkit
      linuxPackages.nvidia_x11
      nvtopPackages.full
    ];

    boot.kernelModules =
      if cpuVendor == "intel"
      then [ "i915" "nvidia" "nvidia_modeset" "nvidia_uvm" "nvidia_drm" ]
      else [ "nvidia" "nvidia_modeset" "nvidia_uvm" "nvidia_drm" ];

    boot.extraModulePackages = [ config.boot.kernelPackages.nvidia_x11 ];

    boot.kernelParams = [
      "nvidia-drm.modeset=1" # Enable DRM kernel mode setting
    ];
  };
}
