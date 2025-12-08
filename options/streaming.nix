{ lib, ... }:

{
  streaming = lib.mkOption {
    description = "Streaming tools (OBS Studio, virtual camera, polkit)";
    default = { };
    type = lib.types.submodule {
      options = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Auto-set to true when any user has graphical.streaming.enable = true (managed by mynixos)";
        };
      };
    };
  };
}
