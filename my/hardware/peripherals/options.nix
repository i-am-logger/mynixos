# Peripheral device profiles.
#
# Declared beside the implementation rather than in the central
# my/hardware/options.nix, so the option exists only where something reads it.
# platforms/linux.nix imports this; the other platform does not, so setting it
# there is the module system's own "does not exist" error rather than silence.
#
# Type-only: my/hardware/options.nix carries `default` and `description` for the
# `hardware` submodule. Two declarations may merge, but only one may carry those,
# or it is a conflicting declaration rather than a merge.

{ lib, ... }:

{
  hardware = lib.mkOption {
    type = lib.types.submodule {
      options = {
        peripherals = {
          elgato = {
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

          keychron = {
            k2-he = {
              enable = lib.mkEnableOption ''
                Keychron K2 HE Hall Effect keyboard.

                Provides udev rules for hidraw access (OpenRGB) and DFU flashing (STM32).

                Vendor: Keychron (3434)
                Product: K2 HE (0e20)
                Bootloader: STM32 DFU (0483:df11)
              '';

              udev = lib.mkOption {
                type = lib.types.bool;
                default = true;
                description = "Enable udev rules for this device. Gated by my.hardware.udev.enable unless set with mkForce.";
              };
            };
          };
        };
      };
    };
  };
}
