# Per-user Hyprland options.
#
# Declared beside the implementation in ./default.nix rather than centrally, so
# the option exists only where something reads it. platforms/linux.nix imports
# this directory; platforms/darwin.nix does not, so a darwin host setting any of
# these gets the module system's "does not exist" rather than a silent no-op --
# which matters here, because Hyprland is the single largest block of options
# that macOS can never honour.

{ lib, ... }:

let
  appLib = import ../../../lib/app-options.nix { inherit lib; };
  inherit (appLib) floatBetween;
in
{
  options.my.users = lib.mkOption {
    type = lib.types.attrsOf (lib.types.submodule {
      options.apps.graphical.windowManagers.hyprland = appLib.mkAppOption {
        name = "Hyprland";
        default = false;
        description = "Hyprland window manager";
        persistedDirectories = [ ".config/hypr" ];
        extraOptions = {

          # General settings
          gaps_in = lib.mkOption {
            type = lib.types.ints.unsigned;
            default = 10;
            description = "Inner gaps between windows (pixels)";
          };
          gaps_out = lib.mkOption {
            type = lib.types.ints.unsigned;
            default = 10;
            description = "Outer gaps between windows and screen edge (pixels)";
          };
          border_size = lib.mkOption {
            type = lib.types.ints.unsigned;
            default = 3;
            description = "Window border size (pixels)";
          };
          layout = lib.mkOption {
            type = lib.types.enum [ "dwindle" "master" ];
            default = "dwindle";
            description = "Default tiling layout";
          };

          # Decoration settings
          rounding = lib.mkOption {
            type = lib.types.ints.unsigned;
            default = 8;
            description = "Corner rounding radius (pixels)";
          };
          active_opacity = lib.mkOption {
            type = floatBetween 0.0 1.0;
            default = 1.0;
            description = "Opacity of focused windows (range: 0.0 to 1.0)";
          };
          inactive_opacity = lib.mkOption {
            type = floatBetween 0.0 1.0;
            default = 1.0;
            description = "Opacity of unfocused windows (range: 0.0 to 1.0)";
          };
          dim_inactive = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "Dim inactive windows";
          };
          dim_strength = lib.mkOption {
            type = floatBetween 0.0 1.0;
            default = 0.3;
            description = "Dim strength for inactive windows (range: 0.0 to 1.0)";
          };

          # Animation settings
          animations_enabled = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "Enable window animations";
          };

          # Blur settings
          blur_enabled = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "Enable background blur";
          };
          blur_size = lib.mkOption {
            type = lib.types.ints.unsigned;
            default = 3;
            description = "Blur size (intensity)";
          };

          # Escape hatch for advanced config
          extraSettings = lib.mkOption {
            type = lib.types.attrsOf lib.types.anything;
            default = { };
            description = "Additional Hyprland settings (passthrough to wayland.windowManager.hyprland.settings)";
          };
        };
      };
    });
  };
}
