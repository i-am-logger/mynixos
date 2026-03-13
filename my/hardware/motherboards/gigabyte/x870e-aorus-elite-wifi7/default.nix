{ config, lib, pkgs, ... }:

let
  cfg = config.my.hardware.motherboards.gigabyte.x870e-aorus-elite-wifi7;
in
{
  imports = [
    ./hardware-configuration.nix
  ];

  config = lib.mkMerge [
    # Import motherboard-specific boot configuration (conditionally)
    (lib.mkIf cfg.enable (import ./drivers/uefi-boot.nix { inherit config lib pkgs; }))

    # Platform architecture (conditionally)
    (lib.mkIf cfg.enable {
      nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";

      # Networking configuration
      networking.useDHCP = lib.mkIf cfg.networking.enable (lib.mkDefault cfg.networking.useDHCP);
      networking.wireless.enable = lib.mkIf cfg.networking.enable (lib.mkDefault cfg.networking.wireless.enable);
    })

    # Set hardware types and component options (unconditionally to avoid recursion)
    {
      # Set hardware types (triggers AMD CPU/GPU modules when motherboard is enabled)
      my.hardware = {
        cpu = lib.mkIf cfg.enable "amd";
        gpu = lib.mkIf cfg.enable "amd";

        # Bluetooth configuration
        bluetooth.enable = lib.mkIf cfg.enable cfg.bluetooth.enable;

        # Storage configuration
        storage = {
          nvme.enable = lib.mkIf cfg.enable cfg.storage.nvme.enable;
          sata.enable = lib.mkIf cfg.enable cfg.storage.sata.enable;
          usb.enable = lib.mkIf cfg.enable cfg.storage.usb.enable;
          # Auto-enable SSD optimizations when NVMe storage is enabled
          ssd.enable = lib.mkIf cfg.enable (lib.mkDefault cfg.storage.nvme.enable);
        };

        # USB configuration
        usb = {
          xhci.enable = lib.mkIf cfg.enable cfg.usb.xhci.enable;
          thunderbolt.enable = lib.mkIf cfg.enable cfg.usb.thunderbolt.enable;
          hid.enable = lib.mkIf cfg.enable cfg.usb.hid.enable;
        };

        # Memory optimization
        memory.optimization.enable = lib.mkIf cfg.enable cfg.memory.optimization.enable;
      };
    }
  ];
}
