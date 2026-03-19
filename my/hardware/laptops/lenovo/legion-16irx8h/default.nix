{ config, lib, pkgs, modulesPath, ... }:

with lib;

let
  cfg = config.my.hardware.laptops.lenovo.legion-16irx8h;
in
{
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
  ];

  config = mkMerge [
    # Auto-enable hardware modules based on laptop options (unconditional to avoid recursion)
    {
      # Set hardware types (triggers Intel CPU/NVIDIA GPU modules when laptop is enabled)
      my.hardware = {
        cpu = mkIf cfg.enable "intel";
        gpu = mkIf cfg.enable "nvidia";

        # Bluetooth configuration
        bluetooth.enable = mkIf cfg.enable cfg.bluetooth.enable;

        # Storage options
        storage = {
          nvme.enable = mkIf cfg.enable cfg.storage.nvme.enable;
          usb.enable = mkIf cfg.enable cfg.storage.usb.enable;
          # Auto-enable SSD optimizations when NVMe storage is enabled
          ssd.enable = mkIf cfg.enable (mkDefault cfg.storage.nvme.enable);
        };

        # USB options
        usb = {
          xhci.enable = mkIf cfg.enable cfg.usb.xhci.enable;
          thunderbolt.enable = mkIf cfg.enable cfg.usb.thunderbolt.enable;
          hid.enable = mkIf cfg.enable cfg.usb.hid.enable;
        };
      };
    }

    (mkIf cfg.enable (mkMerge [
      # Import laptop-specific driver configurations
      (import ./drivers/uefi-boot.nix { inherit config lib pkgs; })
      (import ./drivers/realtek-audio.nix { inherit pkgs; })
      (import ./drivers/network.nix { inherit lib; })
      (import ./drivers/nvidia-rtx4080.nix { inherit lib; })
      (import ./drivers/intel-13900hx-cpu.nix { inherit config lib; })
      # Windows dual-boot is handled by my.system.dualBoot.windows

      # Additional laptop configuration
      {
        # i915 for Intel iGPU in hybrid mode (kvm-intel handled by intel-13900hx-cpu driver)
        boot.kernelModules = [ "i915" ];

        # Hybrid graphics: Intel iGPU + NVIDIA dGPU
        services.xserver.videoDrivers = [ "intel" "nvidia" ];

        hardware = {
          graphics.extraPackages = with pkgs; [
            intel-media-driver
            vpl-gpu-rt
          ];

          # NVIDIA PRIME configuration for hybrid graphics (laptop-specific)
          nvidia.prime = {
            intelBusId = "PCI:0:2:0";
            nvidiaBusId = "PCI:1:0:0";
            offload.enable = mkForce false;
            offload.enableOffloadCmd = mkForce false;
            sync.enable = true; # Use PRIME sync mode for better performance
          };

          # Intel microcode handled by intel-13900hx-cpu driver
        };

        # Platform architecture
        nixpkgs.hostPlatform = mkDefault "x86_64-linux";
      }
    ]))
  ];
}
