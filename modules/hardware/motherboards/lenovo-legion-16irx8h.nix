{ config, lib, pkgs, modulesPath, ... }:

with lib;

let
  cfg = config.my.hardware.motherboard;
in
{
  config = mkIf (cfg == "lenovo-legion-16irx8h") {
    imports = [
      (modulesPath + "/installer/scan/not-detected.nix")
    ];

    # Hardware configuration
    boot.initrd.availableKernelModules = [ "xhci_pci" "nvme" "thunderbolt" "usbhid" "usb_storage" "sd_mod" ];
    boot.initrd.kernelModules = [ ];
    boot.kernelModules = [ "kvm-intel" ];
    boot.extraModulePackages = [ ];

    # UEFI boot configuration for Lenovo Legion Pro 7 16IRX8H
    boot.loader.systemd-boot.enable = lib.mkForce false;
    boot.loader.efi.canTouchEfiVariables = true;
    boot.loader.systemd-boot.configurationLimit = 10;
    boot.loader.timeout = 2; # Fast boot

    # Use latest kernel
    boot.kernelPackages = pkgs.linuxPackages_latest;

    # Windows dual-boot hardware configuration
    # Hardware-level settings needed for dual-boot with Windows

    # Keep hardware clock in local time (Windows expects this)
    time.hardwareClockInLocalTime = true;

    # Support NTFS filesystem (for Windows partition)
    boot.supportedFilesystems = [ "ntfs" ];

    # Mount Windows partition (read-only for safety)
    fileSystems."/home/logger/mnt/windows" = {
      device = "/dev/disk/by-uuid/A03C41603C413318";
      fsType = "ntfs";
      options = [ "ro" "uid=1000" "gid=100" "dmask=022" "fmask=133" ];
      noCheck = true;
    };

    # Filesystem configuration
    fileSystems."/" = {
      device = "/dev/disk/by-uuid/a1633b72-8485-47dc-a52b-ecd35f2e6d03";
      fsType = "ext4";
    };

    fileSystems."/boot" = {
      device = "/dev/disk/by-uuid/D797-9E9E";
      fsType = "vfat";
      options = [ "fmask=0077" "dmask=0077" ];
    };

    swapDevices = [ ];

    # Networking
    networking.useDHCP = lib.mkDefault true;

    # Platform architecture
    nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
    hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;

    # Mask audit-rules service (cosmetic fix for this hardware)
    # Rules are loaded early via kernel cmdline
    systemd.services.audit-rules.enable = false;

    # NVIDIA PRIME configuration for hybrid graphics
    hardware.nvidia.prime = {
      intelBusId = "PCI:0:2:0";
      nvidiaBusId = "PCI:1:0:0";
    };

    # Set hardware options
    my.hardware = {
      cpu = "intel";
      gpu = "nvidia";
      audio.enable = true;
      bluetooth.enable = true;
      network.enable = true;
      boot = {
        uefi = true;
        secure = false; # Secure boot not enabled on this system
      };
    };
  };
}
