# my.hardware.display: the arrangement half.
#
# Kept apart from the hardware half, as KWin (outputs vs setups) and GNOME
# (monitorspec vs logicalmonitor) do:
#
#   monitors.<vendor>.<model>.<name>  what is plugged in -- each model declares
#                                     its own option in ./monitors/<vendor>/<model>
#   monitors.generic.<name>           a display with no model profile yet
#   layout.<name>                     where the monitor named <name> sits and
#                                     what it shows
#
# Type-only: my/hardware/options.nix carries `default` and `description` for the
# `hardware` submodule.
{ lib, ... }:

let
  inherit (lib) mkOption types;
  inherit (import ../../../lib/app-options.nix { inherit lib; }) floatBetween;

  relative = types.submodule {
    options = {
      x = mkOption { type = types.nullOr types.int; default = null; description = "Absolute x, in logical pixels. Set with y."; };
      y = mkOption { type = types.nullOr types.int; default = null; description = "Absolute y, in logical pixels. Set with x."; };
      leftOf = mkOption { type = types.nullOr types.str; default = null; description = "Place immediately left of the named monitor."; };
      rightOf = mkOption { type = types.nullOr types.str; default = null; description = "Place immediately right of the named monitor."; };
      above = mkOption { type = types.nullOr types.str; default = null; description = "Place immediately above the named monitor."; };
      below = mkOption { type = types.nullOr types.str; default = null; description = "Place immediately below the named monitor."; };
      align = mkOption {
        type = types.enum [ "start" "center" "end" ];
        default = "start";
        description = "Alignment along the shared edge: top/left, centred, or bottom/right.";
      };
    };
  };
in
{
  hardware = mkOption {
    type = types.submodule {
      options.display.layout = mkOption {
        type = types.attrsOf (types.submodule {
          options = {
            position = mkOption {
              type = types.either (types.enum [ "auto" ]) relative;
              default = "auto";
              example = { rightOf = "main"; align = "center"; };
              description = ''
                "auto", absolute `{ x; y; }`, or one of `leftOf`/`rightOf`/
                `above`/`below` naming another monitor, with `align`.
                Relative placement needs a concrete mode -- an exact `mode`, or
                a model profile's native mode -- on both monitors. Positions are
                normalised so the top-left monitor is at 0,0.
              '';
            };

            scale = mkOption {
              type = types.coercedTo types.int (x: x * 1.0) (floatBetween 0.25 10.0);
              default = 1.0;
              description = ''
                Scale factor. The mode divided by it must be whole logical
                pixels, which Hyprland requires.
              '';
            };

            transform = {
              rotation = mkOption {
                type = types.enum [ 0 90 180 270 ];
                default = 0;
                description = "Rotation in degrees, counter-clockwise.";
              };

              flipped = mkOption {
                type = types.bool;
                default = false;
                description = "Mirror the image horizontally (applied before rotation).";
              };
            };

            mirror = mkOption {
              type = types.nullOr types.str;
              default = null;
              description = "Show the named monitor's content instead of a space of its own.";
            };

            enable = mkOption {
              type = types.bool;
              default = true;
              description = "false keeps the monitor dark.";
            };

            workspaces = mkOption {
              type = types.listOf types.ints.positive;
              default = [ ];
              example = [ 1 2 3 ];
              description = "Workspaces that live on this monitor; the first is its default.";
            };
          };
        });
        default = { };
        description = ''
          Arrangement of the monitors declared under `monitors`, keyed by
          instance name. A monitor with no entry is placed automatically at
          scale 1.
        '';
      };
    };
  };
}
