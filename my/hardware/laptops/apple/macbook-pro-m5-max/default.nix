# Apple MacBook Pro (M5 Max).
#
# Composes the same way my/hardware/laptops/lenovo/legion-16irx8h does: the model
# profile flips the generic `my.hardware.*` category options, and those pull in
# the vendor implementations.
#
# It is much smaller than the Linux profiles for the obvious reason -- macOS owns
# every driver, so there is no microcode, no kernel module, no udev rule and no
# firmware to declare. What is left is genuinely machine-specific: the
# architecture, the fingerprint sensor, and the audio hardware.
#
# Notably absent: `(modulesPath + "/installer/scan/not-detected.nix")`, which the
# lenovo profile imports and which is NixOS-only.
{ config, lib, ... }:

let
  cfg = config.my.hardware.laptops.apple.macbook-pro-m5-max;
in
{
  config = lib.mkMerge [
    # Auto-enable the generic hardware modules. Unconditional (with mkIf per
    # value) rather than wrapped in a single mkIf, to avoid recursion -- the same
    # pattern the lenovo profile uses.
    {
      my.hardware = {
        # Apple Silicon: CPU and GPU are one die. Declared as metadata; there is
        # no my/hardware/{cpu,gpu}/apple implementation because macOS needs none.
        cpu = lib.mkIf cfg.enable "apple";
        gpu = lib.mkIf cfg.enable "apple";

        biometrics.enable = lib.mkIf cfg.enable cfg.biometrics.enable;
        audio.maxSampleRate.enable = lib.mkIf cfg.enable cfg.audio.maxSampleRate;
      };
    }

    (lib.mkIf cfg.enable {
      # Every M-series machine is aarch64. Setting it here rather than in the
      # host config is what lets mkSystem take no `system` argument on darwin,
      # exactly as on NixOS where hardware modules determine the platform.
      nixpkgs.hostPlatform = lib.mkDefault "aarch64-darwin";
    })
  ];
}
