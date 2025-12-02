# Proposed updated default.nix for nixos-hardware/lenovo/legion/16irx8h
# This adds the audio fix that should be contributed upstream

{ lib
, config
, ...
}:
{
  imports = [
    ../../../common/cpu/intel
    ../../../common/gpu/nvidia/prime.nix
    ../../../common/gpu/nvidia/ada-lovelace
    ../../../common/pc/laptop
    ../../../common/pc/ssd
    ../../../common/hidpi.nix
  ];

  boot.initrd.kernelModules = [ "nvidia" ];
  boot.extraModulePackages = [
    config.boot.kernelPackages.lenovo-legion-module
    config.boot.kernelPackages.nvidia_x11
  ];

  # Audio fix for Legion Pro 7 16IRX8H - force specific codec model
  # This fixes the audio issue where speakers don't work out of the box
  boot.extraModprobeConfig = ''
    options snd-hda-intel model=lenovo-legion-7i
  '';

  hardware = {
    nvidia = {
      modesetting.enable = lib.mkDefault true;
      powerManagement.enable = lib.mkDefault true;
      #
      prime = {
        intelBusId = "PCI:00:02:0";
        nvidiaBusId = "PCI:01:00:0";
      };
    };
  };

  # Cooling management
  services.thermald.enable = lib.mkDefault true;

  # √(2560² + 1600²) px / 16 in ≃ 189 dpi
  services.xserver.dpi = 189;
}
