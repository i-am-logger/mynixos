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
    kernelModules = [ "kvm-intel" "i915" ]; # i915 for Intel iGPU in hybrid mode
    extraModulePackages = [ ];
  };

  # Hybrid graphics: Intel iGPU + NVIDIA dGPU
  services.xserver.videoDrivers = [ "intel" "nvidia" ];

  hardware.graphics.extraPackages = with pkgs; [
    intel-media-driver
    vpl-gpu-rt
  ];

  # NVIDIA PRIME configuration for hybrid graphics (laptop-specific)
  hardware.nvidia.prime = {
    intelBusId = "PCI:0:2:0";
    nvidiaBusId = "PCI:1:0:0";
    offload.enable = lib.mkForce false;
    offload.enableOffloadCmd = lib.mkForce false;
    sync.enable = true; # Use PRIME sync mode for better performance
  };

  # Intel microcode updates
  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;

  # Networking - enable DHCP by default
  networking.useDHCP = lib.mkDefault true;

  # Platform architecture
  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
