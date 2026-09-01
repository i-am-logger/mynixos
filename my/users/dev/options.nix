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
          description = "Enable development tools (containers, binfmt, dev packages)";
        };

        containers = lib.mkOption {
          description = "Container tooling for this account";
          default = { };
          type = lib.types.submodule {
            options = {
              enable = lib.mkOption {
                type = lib.types.bool;
                default = true;
                description = ''
                  Install the container runtime for this account (opinionated
                  default: enabled when dev.enable = true). WHICH runtime is the
                  host-wide my.dev.containers.backend option — podman by
                  default, so the account needs no root-equivalent group.
                '';
              };
            };
          };
        };
      };
    };
  };
}
