# Elgato peripheral options.
#
# Declared beside their implementations (./streamdeck, ./game-capture-4k-x)
# rather than in ../options.nix. platforms/linux.nix loads this with
# mkOptionsModule; type-only, because my/hardware/options.nix carries the
# `hardware` submodule's default and description.

{ lib, ... }:

{
  hardware = lib.mkOption {
    type = lib.types.submodule {
      options = {
        peripherals = {
          elgato = {
            game-capture-4k-x = {
              enable = lib.mkEnableOption ''
                Elgato Game Capture 4K X (HDMI 2.1 capture card, USB).

                Capture works through the kernel's uvcvideo with no setup. This
                adds a uaccess udev rule so the logged-in user can open the
                card's USB device read-write, which vendor-control tools need
                (elgato4k-linux: HDR tone mapping, EDID mode) -- without it
                they only run as root.

                Vendor: Elgato Systems (0fd9)
                Product: Game Capture 4K X (009b, or 009c/009d by USB speed mode)
              '';

              # The card in a host's HDMI chain (host -> 4K X -> monitor) does not
              # report ELD, so HDMI audio and the monitor's capabilities go missing
              # on that connector. Forcing the downstream monitor's EDID and keeping
              # HDMI audio pins up restores both.
              passthrough = {
                output = lib.mkOption {
                  type = lib.types.nullOr lib.types.str;
                  default = null;
                  example = "HDMI-A-1";
                  description = "The DRM connector this host feeds the card's HDMI input from, or null when the card is not in this host's display chain (e.g. capture over USB only).";
                };
                edid = lib.mkOption {
                  type = lib.types.path;
                  default = ./game-capture-4k-x/edid/hdmi-audio.bin;
                  description = "EDID forced onto passthrough.output: the monitor behind the card. Defaults to the Dell AW3225QF's HDMI EDID.";
                };
              };
            };

            streamdeck = {
              enable = lib.mkOption {
                type = lib.types.bool;
                default = false;
                description = ''
                  Enable Elgato Stream Deck support (all models).

                  Provides udev rules, streamdeck-ui package, and Qt/Wayland integration
                  for Stream Deck programmable macro pads (Original, Mini, XL, V2, MK.2, Plus).

                  Vendor: Elgato Systems (0fd9)
                  Device type: USB HID programmable control surface
                '';
              };
            };
          };
        };
      };
    };
  };
}
