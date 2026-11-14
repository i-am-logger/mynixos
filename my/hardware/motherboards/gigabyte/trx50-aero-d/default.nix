{ config, lib, ... }:

with lib;

let
  cfg = config.my.hardware.motherboards.gigabyte.trx50-aero-d;
in
{
  imports = [
    ./hardware-configuration.nix
  ];

  # DELIBERATELY NO drivers/ DIRECTORY, unlike the X870E profile beside this one.
  # Both of that board's driver files are specific to that machine rather than to
  # the board, and copying either here would be a regression:
  #
  #   drivers/amd-integrated-gpu.nix clears the GFXOFF bit in amdgpu's
  #   ppfeaturemask and sets deep_color for an OLED panel. Those are workarounds
  #   for a Raphael (RDNA2) *integrated* GPU. sTR5 Threadripper has no iGPU at
  #   all, so the only display adapter is whatever discrete card sits in a slot,
  #   and the generic my/hardware/gpu/amd module (activated by `gpu = "amd"`
  #   below) is the whole story. A board-level quirk file would apply one card's
  #   workarounds to every card this board might ever hold.
  #
  #   drivers/uefi-boot.nix sets `boot.loader.systemd-boot.enable = mkForce false`
  #   "for lanzaboote". my/hardware/boot/uefi already makes exactly that decision,
  #   and makes it correctly -- systemd-boot ON when secure boot is off, mkForce
  #   OFF when it is on. The board-level mkForce is unconditional, so on a host
  #   with secure boot disabled it beats that module's normal-priority `enable =
  #   true` and leaves the machine with NO BOOTLOADER. Nothing about a bootloader
  #   is a property of a motherboard; this profile does not touch it.

  config = mkMerge [
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
