{ lib, ... }:

{
  options.dev = lib.mkOption {
    description = "Development tools configuration";
    default = { };
    type = lib.types.submodule {
      options = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Enable development tools (Docker, binfmt, dev packages)";
        };

        docker = lib.mkOption {
          description = "Docker configuration";
          default = { };
          type = lib.types.submodule {
            options = {
              enable = lib.mkOption {
                type = lib.types.bool;
                default = true;
                description = "Enable Docker with rootless support (opinionated default: enabled when dev.enable = true)";
              };
            };
          };
        };
      };
    };
  };
}
