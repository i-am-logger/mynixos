{ config, lib, pkgs, ... }:

{
  # NVIDIA RTX 4080 Laptop GPU configuration
  # TODO: Add NVIDIA-specific configuration when needed

  # Enable graphics support
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };
}
