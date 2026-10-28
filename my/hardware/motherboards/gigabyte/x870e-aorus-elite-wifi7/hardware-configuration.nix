# Hardware configuration for Gigabyte X870E AORUS Elite WiFi7
# Most hardware configuration is now handled by component modules
{ config
, lib
, pkgs
, modulesPath
, ...
}:

let
  cfg = config.my.hardware.motherboards.gigabyte.x870e-aorus-elite-wifi7;
in
{
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
  ];

  # Everything below is gated on the board being the one in the machine. A
  # module's `imports` cannot be conditional, so this file is evaluated on every
  # host that has the motherboard set in scope — ungated, its kernel params and
  # firmware would land on hardware that has neither this chipset nor this
  # board's HDMI wiring.
  config = lib.mkIf cfg.enable {
    # Boot module packages (empty for this motherboard)
    boot.extraModulePackages = [ ];

    boot.kernelParams = [
      "amdgpu.audio=1"
      # Force HDMI audio to work without valid ELD (bypasses monitor detection)
      "snd_hda_codec_hdmi.enable_all_pins=1"
      "snd_hda_codec_hdmi.static_hdmi_pcm=1"
      # Force EDID firmware for HDMI-A-1 (fixes ELD detection with Elgato capture card)
      "drm.edid_firmware=HDMI-A-1:edid/hdmi-audio.bin"
      # Force enable HDMI-A-1 connector regardless of hotplug detection
      "video=HDMI-A-1:e"
    ];

    # Custom EDID firmware for HDMI audio fix (Elgato 4K X doesn't report ELD properly)
    hardware.firmware = [
      (pkgs.runCommand "hdmi-edid-firmware" { } ''
        mkdir -p $out/lib/firmware/edid
        cp ${./firmware/edid/hdmi-audio.bin} $out/lib/firmware/edid/hdmi-audio.bin
      '')
    ];
  };
}
