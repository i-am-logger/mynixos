# Unified theming options
# Defines my.theming.* — vogix is the theming system (Linux/Hyprland).
{ lib, ... }:

let
  inherit (import ../../lib/app-options.nix { inherit lib; }) floatBetween;
in
{
  theming = lib.mkOption {
    description = "Theming configuration";
    default = { };
    type = lib.types.submodule {
      options = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Enable theming system (defaults to vogix)";
        };

        # Vogix runtime theme management
        vogix = lib.mkOption {
          description = "Vogix runtime theme management configuration";
          default = { };
          type = lib.types.submodule {
            options = {
              enable = lib.mkOption {
                type = lib.types.bool;
                default = true;
                description = "Enable vogix runtime theme management (default when theming.enable = true)";
              };
            };
          };
        };

        # Hypr-vogix monochromatic screen overlay
        hypr-vogix = lib.mkOption {
          description = "Hypr-vogix monochromatic screen overlay for Hyprland";
          default = { };
          type = lib.types.submodule {
            options = {
              enable = lib.mkEnableOption "hypr-vogix monochromatic screen overlay";

              defaultTheme = lib.mkOption {
                type = lib.types.str;
                default = "walnut";
                description = "Default theme to apply (e.g., walnut, military, amber, cyber, arctic)";
              };

              defaultOpacity = lib.mkOption {
                type = floatBetween 0.0 1.0;
                default = 0.5;
                description = "Default overlay intensity (0.0 = no effect, 1.0 = full monochrome)";
              };

              defaultBrightness = lib.mkOption {
                type = floatBetween 0.1 2.0;
                default = 1.0;
                description = "Default brightness (0.1 = very dark, 1.0 = normal, 2.0 = max bright)";
              };

              defaultSaturation = lib.mkOption {
                type = floatBetween 0.0 2.0;
                default = 1.0;
                description = "Default color saturation (0.0 = gray, 1.0 = normal, 2.0 = vivid)";
              };

              defaultInvert = lib.mkOption {
                type = lib.types.nullOr (lib.types.enum [ "oklab" "okhsl" "hsv" ]);
                default = null;
                description = "Default lightness inversion algorithm (null = no inversion)";
              };
            };
          };
        };

        # OpenRGB hardware RGB lighting control
        openrgb = lib.mkOption {
          description = "OpenRGB hardware RGB lighting control";
          default = { };
          type = lib.types.submodule {
            options = {
              enable = lib.mkOption {
                type = lib.types.bool;
                default = true;
                description = "Enable OpenRGB for hardware RGB lighting control (keyboards, coolers, motherboards)";
              };

              qmkDevices = lib.mkOption {
                type = lib.types.listOf (lib.types.submodule {
                  options = {
                    name = lib.mkOption {
                      type = lib.types.str;
                      description = "Device name for OpenRGB display";
                    };
                    vid = lib.mkOption {
                      type = lib.types.str;
                      description = "USB Vendor ID (e.g. \"0x3434\")";
                    };
                    pid = lib.mkOption {
                      type = lib.types.str;
                      description = "USB Product ID (e.g. \"0x0E20\")";
                    };
                  };
                });
                default = [ ];
                description = "QMK keyboards with OpenRGB firmware support. Hardware modules append to this list.";
              };
            };
          };
        };

      };
    };
  };
}
