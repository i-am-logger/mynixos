{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.my.hardware.motherboards.gigabyte.x870e-aorus-elite-wifi7;
in
{
  imports = [
    ./hardware-configuration.nix
  ];

  config = mkMerge [
    # Import motherboard-specific boot configuration (conditionally)
    (mkIf cfg.enable (import ./drivers/uefi-boot.nix { inherit config lib pkgs; }))

    # Platform architecture (conditionally)
    (mkIf cfg.enable {
      nixpkgs.hostPlatform = mkDefault "x86_64-linux";

      # Networking configuration
      networking.useDHCP = mkIf cfg.networking.enable (mkDefault cfg.networking.useDHCP);
      networking.wireless.enable = mkIf cfg.networking.enable (mkDefault cfg.networking.wireless.enable);
    })

    # Set hardware types and component options (unconditionally to avoid recursion)
    {
      # Set hardware types (triggers AMD CPU/GPU modules when motherboard is enabled)
      my.hardware = {
        cpu = mkIf cfg.enable "amd";
        gpu = mkIf cfg.enable "amd";

        # Bluetooth configuration
        bluetooth.enable = mkIf cfg.enable cfg.bluetooth.enable;

        # Storage configuration
        storage = {
          nvme.enable = mkIf cfg.enable cfg.storage.nvme.enable;
          sata.enable = mkIf cfg.enable cfg.storage.sata.enable;
          usb.enable = mkIf cfg.enable cfg.storage.usb.enable;
          # Auto-enable SSD optimizations when NVMe storage is enabled
          ssd.enable = mkIf cfg.enable (mkDefault cfg.storage.nvme.enable);
        };

        # USB configuration
        usb = {
          xhci.enable = mkIf cfg.enable cfg.usb.xhci.enable;
          thunderbolt.enable = mkIf cfg.enable cfg.usb.thunderbolt.enable;
          hid.enable = mkIf cfg.enable cfg.usb.hid.enable;
        };

        # Memory optimization
        memory.optimization.enable = mkIf cfg.enable cfg.memory.optimization.enable;
      };
    }
  ];
}
