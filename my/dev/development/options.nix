{ lib, ... }:

{
  dev = lib.mkOption {
    description = "Development tools (Docker, binfmt, AppImage support)";
    default = { };
    type = lib.types.submodule {
      options = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Auto-set to true when any user has dev = true (managed by mynixos)";
        };
      };
    };
  };
}
