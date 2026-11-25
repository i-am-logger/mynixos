# What every monitor instance has, whatever its model: identity, mode, VRR,
# bit depth and HDR.
#
# A submodule MODULE, not an option: each model under ./monitors declares
# `monitors.<vendor>.<model> = attrsOf (submodule [ ./monitor-options.nix
# ./model.nix ])`, and its model.nix layers the panel's facts on top with
# mkDefault. So the precedence is: these built-in defaults, then the model's
# facts, then the host.
#
# The built-in defaults are the owner's preference -- the highest resolution and
# then the highest refresh rate, 10-bit HDR with SDR content at 203 nits, VRR
# for fullscreen -- and they double as the compositor's wildcard rule for any
# display nobody declared.
#
# Compositor-neutral: nothing here names Hyprland. my/graphical/hyprland renders
# it.
{ lib, ... }:

let
  inherit (lib) mkOption types;
  inherit (import ../../../lib/app-options.nix { inherit lib; }) floatBetween;

  # A float option that also takes a whole number, so `brightness = 1;` works.
  real = min: max: types.coercedTo types.int (x: x * 1.0) (floatBetween min max);

  nits = types.addCheck types.number (x: x >= 0) // { description = "non-negative number (nits)"; };

  concreteMode = types.submodule {
    options = {
      width = mkOption { type = types.ints.positive; description = "Horizontal resolution in pixels."; };
      height = mkOption { type = types.ints.positive; description = "Vertical resolution in pixels."; };
      refresh = mkOption { type = types.number; description = "Refresh rate in Hz, as the compositor lists it (e.g. 239.99)."; };
    };
  };
in
{
  options = {
    make = mkOption {
      type = types.nullOr types.str;
      default = null;
      example = "Dell Inc.";
      description = ''
        Manufacturer as the compositor reports it from EDID. A model profile
        sets this; set it yourself only under `monitors.generic`.
      '';
    };

    model = mkOption {
      type = types.nullOr types.str;
      default = null;
      example = "AW3225QF";
      description = ''
        Model name as the compositor reports it from EDID. A model profile sets
        this; set it yourself only under `monitors.generic`.
      '';
    };

    serial = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = ''
        EDID serial. Narrows the match to one panel, which is how two identical
        monitors are told apart.
      '';
    };

    output = mkOption {
      type = types.nullOr types.str;
      default = null;
      example = "DP-1";
      description = ''
        Connector to pin this instance to. When set it is the whole selector,
        and make/model/serial are not used to find the monitor.
      '';
    };

    nativeMode = mkOption {
      type = types.nullOr concreteMode;
      default = null;
      internal = true;
      description = ''
        The panel's native mode, set by its model profile. Placement uses it
        when `mode` is "highres" or "preferred".
      '';
    };

    mode = mkOption {
      type = types.either (types.enum [ "highres" "preferred" ]) concreteMode;
      default = "highres";
      example = { width = 3840; height = 2160; refresh = 239.99; };
      description = ''
        "highres" (highest resolution, then highest refresh), "preferred" (the
        EDID's preferred mode), or an exact mode.
      '';
    };

    vrr = mkOption {
      type = types.enum [ "off" "on" "fullscreen" ];
      default = "fullscreen";
      description = "Variable refresh rate: never, always, or for fullscreen windows only.";
    };

    bitDepth = mkOption {
      type = types.enum [ 8 10 ];
      default = 10;
      description = "Bits per colour channel on the link. HDR needs 10.";
    };

    hdr = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = ''
          Drive the monitor in HDR (PQ, BT.2020). A monitor whose EDID declares
          no HDR support falls back to sRGB in the compositor.
        '';
      };

      gamut = mkOption {
        type = types.nullOr (types.enum [ "srgb" "wide" ]);
        default = null;
        description = ''
          Colour gamut when HDR is off. null leaves it to the compositor.
        '';
      };

      sdr = {
        referenceWhite = mkOption {
          type = types.ints.positive;
          default = 203;
          description = ''
            Luminance in nits that SDR white maps to under HDR. 203 is BT.2408's
            reference white; much lower makes SDR content look dim.
          '';
        };

        brightness = mkOption {
          type = real 0.0 4.0;
          default = 1.0;
          description = "Multiplier on SDR content's brightness under HDR.";
        };

        saturation = mkOption {
          type = real 0.0 4.0;
          default = 1.0;
          description = "Multiplier on SDR content's saturation under HDR.";
        };
      };

      luminance = {
        min = mkOption {
          type = types.nullOr nits;
          default = null;
          description = "Override the EDID's minimum luminance, in nits. null uses the EDID.";
        };

        max = mkOption {
          type = types.nullOr types.ints.positive;
          default = null;
          description = "Override the EDID's peak luminance, in nits. null uses the EDID.";
        };

        maxAverage = mkOption {
          type = types.nullOr types.ints.positive;
          default = null;
          description = "Override the EDID's maximum frame-average luminance, in nits. null uses the EDID.";
        };
      };

      icc = mkOption {
        type = types.nullOr types.path;
        default = null;
        description = ''
          ICC profile for SDR colour management. Excludes `hdr.enable`.
        '';
      };
    };
  };
}
