# mynixos Opinionated Defaults: User Environment, Linux
#
# The launcher and locker selectors, split out of ./mynixos.nix.
#
# They are Hyprland-specific (walker is a Wayland launcher; hyprlock is
# Hyprland's screen locker), and unlike the other selectors they name the package
# in the option VALUE. That means `pkgs.walker` / `pkgs.hyprlock` would be forced
# on darwin the moment anything read the option -- neither has an aarch64-darwin
# build. Keeping them in a file that only platforms/linux.nix imports removes
# that hazard outright, rather than relying on laziness or on a `mkIf isLinux`
# that still leaves the package reference in the value.

{ lib, pkgs, ... }:

{
  options.my.users = lib.mkOption {
    type = lib.types.attrsOf (lib.types.submodule ({ config, ... }: {
      config = lib.mkIf (config.graphical.enable or false) {
        environment = {
          launcher = lib.mkDefault {
            enable = true;
            package = pkgs.walker;
            settings = { };
          };
          locker = lib.mkDefault {
            enable = true;
            package = pkgs.hyprlock;
            settings = { };
          };
        };
      };
    }));
  };
}
