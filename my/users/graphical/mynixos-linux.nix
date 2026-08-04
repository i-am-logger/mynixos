# mynixos Opinionated Defaults: Graphical Apps, Linux
#
# The Wayland/X11 half of ./mynixos.nix: a compositor, its status bar, and an X11
# image viewer. None has a macOS counterpart, and their options are declared
# Linux-only, so defaulting them on from the shared injector would set options
# that do not exist on darwin.
#
# Imported only by platforms/linux.nix.

{ lib, ... }:

{
  options.my.users = lib.mkOption {
    type = lib.types.attrsOf (lib.types.submodule ({ config, ... }: {
      config = lib.mkIf (config.graphical.enable or false) {
        apps.graphical = {
          windowManagers.hyprland.enable = lib.mkDefault true;
          statusbars.waybar.enable = lib.mkDefault true;
          viewers.feh.enable = lib.mkDefault true;
        };
      };
    }));
  };
}
