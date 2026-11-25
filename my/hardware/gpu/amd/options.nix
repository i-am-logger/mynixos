# AMD GPU switches that belong to the display domain, declared here because
# ./default.nix is what implements them.
#
# Type-only: my/hardware/options.nix carries `default` and `description` for the
# `hardware` submodule.
{ lib, ... }:

{
  hardware = lib.mkOption {
    type = lib.types.submodule {
      options.display.hdmiFrl.enable = lib.mkEnableOption ''
        HDMI 2.1 FRL (Fixed Rate Link) on amdgpu. Without it an HDMI 2.1 monitor
        is driven over TMDS, which tops out near 4K@60 10-bit. Needs
        my.hardware.gpu = "amd"; a no-op from Linux 7.4, where FRL is on by
        default
      '';
    };
  };
}
