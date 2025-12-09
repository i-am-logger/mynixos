{ lib, ... }:

{
  graphical = lib.mkOption {
    description = "Graphical environment (Hyprland, display manager, XDG portals)";
    default = { };
    type = lib.types.submodule {
      options = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Auto-set to true when any user has graphical = true (managed by mynixos)";
        };
      };
    };
  };
}
