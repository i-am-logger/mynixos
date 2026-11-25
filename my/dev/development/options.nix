{ lib, ... }:

{
  dev = lib.mkOption {
    description = "Development tools (binfmt, AppImage support). Container engines are my.virtualisation.containers";
    default = { };
    type = lib.types.submodule {
      options = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Auto-set to true when any user has dev.enable = true (managed by mynixos)";
        };

      };
    };
  };
}
