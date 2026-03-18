{ lib, ... }:

with lib;

{
  # NVIDIA RTX 4080 Laptop GPU configuration
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };

  # NVIDIA PRIME is configured in the laptop's default.nix
  # (intelBusId/nvidiaBusId are board-specific)

  hardware.nvidia = {
    modesetting.enable = mkDefault true;
    powerManagement.enable = mkDefault true;
    powerManagement.finegrained = mkDefault false;
    dynamicBoost.enable = mkDefault true;
  };
}
