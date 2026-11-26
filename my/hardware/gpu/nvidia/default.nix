{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.my.hardware.gpu;
in
{
  config = mkIf (cfg == "nvidia") {
    # The driver only. CUDA is not the GPU profile's: whatever uses it
    # (ollama-cuda under my.ai) brings it, and its licence, along.
    my.system.allowedUnfreePackages = [
      "nvidia-x11"
      "nvidia-settings"
      "nvidia-persistenced"
    ];

    # NVIDIA GPU driver configuration
    hardware.graphics = {
      enable = true;
      # No enable32Bit: only Steam/Wine need the 32-bit stack, and nixpkgs'
      # programs.steam turns it on itself.
      extraPackages = with pkgs; [
        libva-vdpau-driver
        libvdpau-va-gl
      ];
    };

    # Video drivers (can be extended by hardware-specific configs)
    services.xserver.videoDrivers = mkDefault [ "nvidia" ];

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

    environment.systemPackages = [ pkgs.nvtopPackages.full ];

    # The module BUILD is hardware.nvidia's: with `open = true` it adds the
    # open module for boot.kernelPackages. Listing the closed nvidia_x11 here
    # too put both builds on the system. It loads only nvidia_uvm itself, so
    # the load list stays.
    boot = {
      kernelModules = [ "nvidia" "nvidia_modeset" "nvidia_uvm" "nvidia_drm" ];

      kernelParams = [
        "nvidia-drm.modeset=1" # Enable DRM kernel mode setting
      ];
    };

    # NVIDIA persistenced service configuration
    systemd.services.nvidia-persistenced = {
      serviceConfig = {
        Restart = lib.mkDefault "on-failure";
        RestartSec = lib.mkDefault "5s";
        ExecStartPre = "${pkgs.kmod}/bin/modprobe nvidia";
      };
    };

    my.system = {
      # Persistence configuration
      persistence.features = {
        systemDirectories = [
          "/var/lib/nvidia-persistenced"
        ];
      };
    };
  };
}
