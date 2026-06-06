{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.my.hardware.gpu;
in
{
  config = mkIf (cfg == "amd") {
    # Generic AMD Radeon GPU enablement — the amdgpu driver + Mesa/VA-API.
    # This module is shared by every AMD-GPU host, so it must stay generic:
    # machine- or iGPU-specific kernel params and quirks (e.g. GFXOFF disable,
    # deep colour for a particular display) belong in the *machine* driver —
    # see the motherboard's drivers/amd-integrated-gpu.nix — not here.
    boot = {
      initrd.kernelModules = [ "amdgpu" ];
      kernelModules = [ "amdgpu" ];
    };

    # Graphics hardware configuration
    hardware.graphics = {
      enable = true;
      enable32Bit = true;
      extraPackages = with pkgs; [
        libvdpau-va-gl
        libva-utils
      ];
    };
  };
}
