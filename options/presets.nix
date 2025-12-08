{ lib, ... }:

{
  presets = lib.mkOption {
    type = lib.types.submodule {
      options = {
        workstation = {
          enable = lib.mkEnableOption "workstation preset with opinionated app defaults";
        };
      };
    };
    default = { };
    description = "Preset configurations";
  };
}
