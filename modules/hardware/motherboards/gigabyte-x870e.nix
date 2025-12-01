{ config, lib, pkgs, modulesPath, ... }:

with lib;

let
  cfg = config.my.hardware.motherboard;
in
{
  config = mkIf (cfg == "gigabyte-x870e") {
    imports = [
      (modulesPath + "/installer/scan/not-detected.nix")
    ];

    # Hardware configuration
    boot.initrd.availableKernelModules = [ "nvme" "ahci" "xhci_pci" "thunderbolt" "usb_storage" "usbhid" "sd_mod" ];
    boot.initrd.kernelModules = [ "amdgpu" ];
    boot.kernelModules = [ "kvm-amd" ];
    boot.extraModulePackages = [ ];

    # Kernel parameters to optimize AMD integrated GPU memory allocation
    boot.kernelParams = [
      "amdgpu.gttsize=8192" # Increase GTT (Graphics Translation Table) size to 8GB
      "amdgpu.vramlimit=4096" # Set VRAM limit to 4GB (adjust based on available system RAM)
      "amdgpu.vis_vramlimit=512" # Visible VRAM limit
      "amdgpu.moverate=1000" # Faster memory movement

      # Memory management optimizations for large models
      "vm.swappiness=10" # Reduce swapping to keep model in RAM
      "vm.dirty_ratio=5" # Reduce dirty page cache to free memory faster
      "vm.dirty_background_ratio=2" # Background dirty page writeback
      "transparent_hugepage=madvise" # Use huge pages only when requested
    ];

    # UEFI boot configuration for Gigabyte X870E motherboard
    boot.loader.systemd-boot.enable = lib.mkForce false;
    boot.loader.efi.canTouchEfiVariables = true;

    # Use latest kernel
    boot.kernelPackages = pkgs.linuxPackages_latest;

    # Networking
    networking.useDHCP = lib.mkDefault true;

    # Platform architecture
    nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
    hardware.cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;

    # AMD GPU support
    hardware.graphics = {
      enable = true;
      enable32Bit = true;
      extraPackages = with pkgs; [
        rocmPackages.clr.icd
      ];
      # Note: amdvlk has been removed, RADV is now the default AMD Vulkan driver
    };

    # Enable ROCm support
    systemd.tmpfiles.rules = [
      "L+    /opt/rocm/hip   -    -    -     -    ${pkgs.rocmPackages.clr}"
    ];

    # Disko configuration (inline from disko.nix)
    disko.devices = {
      nodev = {
        "/" = {
          fsType = "tmpfs";
          mountOptions = [
            "size=16G" # Reduced from 32G to free more RAM for GPU
            "mode=755"
            "noatime" # Reduce disk I/O overhead
          ];
        };
        "/tmp" = {
          fsType = "tmpfs";
          mountOptions = [
            "size=8G" # Moderate size for temporary files
            "mode=755"
            "noatime"
          ];
        };
        # Dedicated tmpfs for GPU compute workloads
        "/tmp/gpu-workdir" = {
          fsType = "tmpfs";
          mountOptions = [
            "size=16G" # Fast storage for GPU temp files
            "mode=755"
            "noatime"
          ];
        };
      };

      disk = {
        main = {
          type = "disk";
          device = "/dev/nvme0n1";
          content = {
            type = "gpt";
            partitions = {
              boot = {
                size = "2M";
                type = "EF02"; # for grub MBR
              };
              ESP = {
                size = "2G";
                type = "EF00";
                content = {
                  type = "filesystem";
                  format = "vfat";
                  mountpoint = "/boot";
                };
              };
              nix = {
                size = "128G"; # Reduced to 128GB, still plenty for nix store
                content = {
                  type = "btrfs";
                  subvolumes = {
                    "/nix" = {
                      mountpoint = "/nix";
                      mountOptions = [
                        "noatime"
                        "compress=zstd"
                        "autodefrag"
                        "space_cache=v2"
                      ];
                    };
                  };
                };
              };
              persist = {
                size = "100%"; # Remaining space for /persist
                content = {
                  type = "btrfs";
                  subvolumes = {
                    "/persist" = {
                      mountpoint = "/persist";
                      mountOptions = [
                        "noatime"
                        "autodefrag"
                        "space_cache=v2"
                      ];
                    };
                  };
                };
              };
            };
          };
        };
      };
    };

    # Set hardware options
    my.hardware = {
      cpu = "amd";
      gpu = "amd";
      audio.enable = true;
      bluetooth.enable = true;
      network.enable = true;
      boot = {
        uefi = true;
        secure = true;
      };
    };
  };
}
