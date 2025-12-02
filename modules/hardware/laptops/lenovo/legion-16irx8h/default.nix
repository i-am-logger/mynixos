{ config, lib, pkgs, modulesPath, ... }:

{
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
    ./drivers/uefi-boot.nix # Laptop-specific kernel config
  ];

  # Hardware specification for this laptop
  my.hardware = {
    cpu = "intel";
    gpu = "nvidia";
    bluetooth.enable = true;
    audio.enable = true;
  };

  # Boot configuration for this laptop hardware
  boot = {
    initrd = {
      availableKernelModules = [ "xhci_pci" "nvme" "thunderbolt" "usbhid" "usb_storage" "sd_mod" ];
      kernelModules = [ ];
    };
    kernelModules = [ "kvm-intel" ];
    extraModulePackages = [ ];
  };

  # NVIDIA PRIME configuration for hybrid graphics (laptop-specific)
  hardware.nvidia.prime = {
    intelBusId = "PCI:0:2:0";
    nvidiaBusId = "PCI:1:0:0";
  };

  # Intel microcode updates
  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;

  # Networking - enable DHCP by default
  networking.useDHCP = lib.mkDefault true;

  # Platform architecture
  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
