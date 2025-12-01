{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.my.hardware.gpu;
in
{
  config = mkIf (cfg == "nvidia") {
    # NVIDIA GPU driver configuration
    # TODO: Add NVIDIA-specific configuration when needed

    # Enable graphics support
    hardware.graphics = {
      enable = true;
      enable32Bit = true;
    };
  };
}
