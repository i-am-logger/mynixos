{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.my.hardware.gpu;
in
{
  config = mkIf (cfg == "nvidia") {
    # NVIDIA GPU driver configuration
    hardware.graphics = {
      enable = true;
      enable32Bit = true;
      extraPackages = with pkgs; [
        libva-vdpau-driver
        libvdpau-va-gl
      ];
    };

    # Video drivers (can be extended by hardware-specific configs)
    services.xserver.videoDrivers = mkDefault [ "nvidia" ];

    nixpkgs.config.cudaSupport = true;

    hardware.nvidia = {
      open = true;
      modesetting.enable = true;
      nvidiaSettings = true;
      nvidiaPersistenced = true;
      dynamicBoost.enable = true;

      # Prime configuration should be set by hardware-specific configs
      # (e.g., laptop modules that know they have hybrid graphics)

      package = config.boot.kernelPackages.nvidiaPackages.stable;
    };

    environment.systemPackages = with pkgs; [
      cudatoolkit
      linuxPackages.nvidia_x11
      nvtopPackages.full
    ];

    # NVIDIA kernel modules
    boot.kernelModules = [ "nvidia" "nvidia_modeset" "nvidia_uvm" "nvidia_drm" ];
    boot.extraModulePackages = [ config.boot.kernelPackages.nvidia_x11 ];

    boot.kernelParams = [
      "nvidia-drm.modeset=1" # Enable DRM kernel mode setting
    ];

    # NVIDIA udev rules for proper device permissions
    services.udev.extraRules = ''
      KERNEL=="nvidia*", GROUP="video", MODE="0666"
      KERNEL=="nvidiactl", GROUP="video", MODE="0666"
    '';

    # NVIDIA persistenced service configuration
    systemd.services.nvidia-persistenced = {
      serviceConfig = {
        Restart = lib.mkDefault "on-failure";
        RestartSec = lib.mkDefault "5s";
        ExecStartPre = "${pkgs.kmod}/bin/modprobe nvidia";
      };
    };

    # Persistence configuration
    my.system.persistence.features = {
      systemDirectories = [
        "/var/lib/nvidia-persistenced"
      ];
    };
  };
}
