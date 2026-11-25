# Dell Alienware AW3225QF: 32" 4K 240 Hz QD-OLED.
#
# my.hardware.display.monitors.dell.aw3225qf.<name>, one entry per panel the
# host has. The model's facts are in ./model.nix; the shared options in
# ../../../monitor-options.nix.
#
# Type-only: my/hardware/options.nix carries `default` and `description` for the
# `hardware` submodule.
{ lib, ... }:

{
  hardware = lib.mkOption {
    type = lib.types.submodule {
      options.display.monitors.dell.aw3225qf = lib.mkOption {
        type = lib.types.attrsOf (lib.types.submodule [ ../../../monitor-options.nix ./model.nix ]);
        default = { };
        description = ''
          Dell AW3225QF monitors, keyed by instance name. Names are shared with
          every model's instances and must be unique across them.
        '';
      };
    };
  };
}
