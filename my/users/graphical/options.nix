{ lib, ... }:

{
  options.graphical = lib.mkOption {
    description = "Graphical environment configuration";
    default = { };
    type = lib.types.submodule {
      options = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Enable graphical environment for this user (auto-enables Hyprland + greetd system services)";
        };



      };
    };
  };
}
