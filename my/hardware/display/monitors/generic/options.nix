# my.hardware.display.monitors.generic.<name>: a display with no model profile
# yet. The same options as any model's instance, with no facts layered on, so it
# must name itself: `output`, or `make` and `model` (asserted by
# my/hardware/display).
#
# Type-only: my/hardware/options.nix carries `default` and `description` for the
# `hardware` submodule.
{ lib, ... }:

{
  hardware = lib.mkOption {
    type = lib.types.submodule {
      options.display.monitors.generic = lib.mkOption {
        type = lib.types.attrsOf (lib.types.submodule ../../monitor-options.nix);
        default = { };
        description = ''
          Displays without a model profile, keyed by instance name. Names are
          shared with every model's instances and must be unique across them.
        '';
      };
    };
  };
}
