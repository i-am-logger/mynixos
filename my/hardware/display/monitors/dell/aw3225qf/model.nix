# The AW3225QF's facts, layered on ../../../monitor-options.nix inside each
# instance. Ports: 1x DP 1.4 (4K@240 10-bit HDR through DSC) and 2x HDMI 2.1 FRL.
# True Black 400 certified, about 1000 nits in its Peak 1000 mode; 99% DCI-P3;
# VRR 48-240 Hz.
{ config, lib, ... }:

let
  inherit (lib) mkDefault mkIf mkOption types;

  native = { width = 3840; height = 2160; refresh = 239.99; };

  # Luminance in nits per HDR mode, as the panel's own EDIDs report it:
  # - trueBlack400: the DP EDID (read on ads-dev1, DP-1), 427 peak / 265 average.
  # - peak1000:     the HDMI EDID, captured with the monitor in Peak 1000 mode
  #                 (yoga's forced EDID), 993 peak / 277 average.
  # The two inputs report different values, so "edid" -- let the compositor read
  # whichever EDID this link has -- is the default.
  luminance = {
    trueBlack400 = { max = 427; maxAverage = 265; };
    peak1000 = { max = 993; maxAverage = 277; };
  };
in
{
  options.hdrMode = mkOption {
    type = types.enum [ "edid" "trueBlack400" "peak1000" ];
    default = "edid";
    description = ''
      The HDR mode selected in the monitor's own menu, so the compositor tone-maps
      to the right peak. "edid" leaves the luminance to the link's EDID.
    '';
  };

  config = {
    make = "Dell Inc.";
    model = "AW3225QF";
    # Geometry for layout placement. The mode itself stays "highres": the
    # driver prunes what a link cannot carry, so the same profile gets 4K@240
    # over DP 1.4 + DSC and 4K@60 over HDMI without FRL. Pinning 239.99 here
    # would ask an HDMI-TMDS link for a mode it does not offer.
    nativeMode = native;

    bitDepth = mkDefault 10;
    hdr.enable = mkDefault true;
    vrr = mkDefault "fullscreen";

    hdr.luminance = mkIf (config.hdrMode != "edid") {
      max = mkDefault luminance.${config.hdrMode}.max;
      maxAverage = mkDefault luminance.${config.hdrMode}.maxAverage;
    };
  };
}
