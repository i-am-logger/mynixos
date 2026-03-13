{ config, lib, pkgs, modulesPath, ... }:

let
  cfg = config.my.hardware.laptops.lenovo.legion-16irx8h;
in
{
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
  ];

  config = lib.mkMerge [
    # Auto-enable hardware modules based on laptop options (unconditional to avoid recursion)
    {
      # Set hardware types (triggers Intel CPU/NVIDIA GPU modules when laptop is enabled)
      my.hardware = {
        cpu = lib.mkIf cfg.enable "intel";
        gpu = lib.mkIf cfg.enable "nvidia";

        # Bluetooth configuration
        bluetooth.enable = lib.mkIf cfg.enable cfg.bluetooth.enable;

        # Storage options
        storage = {
          nvme.enable = lib.mkIf cfg.enable cfg.storage.nvme.enable;
          usb.enable = lib.mkIf cfg.enable cfg.storage.usb.enable;
          # Auto-enable SSD optimizations when NVMe storage is enabled
          ssd.enable = lib.mkIf cfg.enable (lib.mkDefault cfg.storage.nvme.enable);
        };

        # USB options
        usb = {
          xhci.enable = lib.mkIf cfg.enable cfg.usb.xhci.enable;
          thunderbolt.enable = lib.mkIf cfg.enable cfg.usb.thunderbolt.enable;
          hid.enable = lib.mkIf cfg.enable cfg.usb.hid.enable;
        };
      };
    }

    (lib.mkIf cfg.enable (lib.mkMerge [
      # Import laptop-specific boot configuration
      (import ./drivers/uefi-boot.nix { inherit config lib pkgs; })

      # Additional laptop configuration
      {
        # Kernel modules for this laptop hardware
        # Note: Storage and USB modules are now handled via my.hardware.* options above
        boot = {
          initrd.kernelModules = [ ];
          kernelModules = [ "kvm-intel" "i915" ]; # i915 for Intel iGPU in hybrid mode
          extraModulePackages = [ ];
        };

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
            offload.enable = lib.mkForce false;
            offload.enableOffloadCmd = lib.mkForce false;
            sync.enable = true; # Use PRIME sync mode for better performance
          };

          # Intel microcode updates
          cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
        };

        # Networking - enable DHCP by default
        networking.useDHCP = lib.mkDefault true;

        # Platform architecture
        nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
      }
    ]))
  ];
}
