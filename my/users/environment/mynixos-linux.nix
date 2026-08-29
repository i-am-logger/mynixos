# mynixos Opinionated Defaults: User Environment, Linux
#
# The launcher and locker selectors, split out of ./mynixos.nix.
#
# They are Hyprland-specific and, unlike the other selectors, name the
# package in the option VALUE — which would force the package on darwin the
# moment anything read the option. Keeping them in a file only
# platforms/linux.nix imports removes that hazard outright.
#
# The launcher and locker are the vogix shell's own (`pkgs.vogix-launcher`
# / `pkgs.vogix-lock`, via the vogix overlay): the launcher opens the
# shell's overlay (and speaks walker-compatible `--dmenu`), the locker
# engages the shell's WlSessionLock and fails unless the compositor reports
# it SECURE — walker/elephant, hyprlock, waybar and mako are all gone from
# the fleet, each deleted when its vogix surface shipped.

{ lib, pkgs, ... }:

{
  options.my.users = lib.mkOption {
    type = lib.types.attrsOf (lib.types.submodule ({ config, ... }: {
      config = lib.mkIf (config.graphical.enable or false) {
        # pkgs.vogix-{launcher,lock} only exist under the vogix overlay,
        # which the theming gates apply — and both work THROUGH the shell,
        # so they are only sensible defaults when the vogix shell is the
        # selection. A shell = "none" user picks their own tools explicitly.
        environment = lib.mkIf (config.graphical.shell == "vogix") {
          launcher = lib.mkDefault {
            enable = true;
            package = pkgs.vogix-launcher;
            settings = { };
          };
          locker = lib.mkDefault {
            enable = true;
            package = pkgs.vogix-lock;
            settings = { };
          };
        };
      };
    }));
  };
}
