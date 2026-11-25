# my.virtualisation.containers.darwin — Colima settings. darwin only (loaded
# from platforms/darwin.nix): docker on macOS runs in a Linux VM, and these
# configure that VM. Type-only; ../options.nix owns `containers`.
{ lib, ... }:

{
  virtualisation = lib.mkOption {
    type = lib.types.submodule {
      options.containers = lib.mkOption {
        type = lib.types.submodule {
          options.darwin = lib.mkOption {
            description = "darwin-only container settings (Colima)";
            default = { };
            type = lib.types.submodule {
              options.colimaAutoStart = lib.mkOption {
                type = lib.types.bool;
                default = false;
                description = ''
                  Start the Colima VM at login via a launchd agent. Off by
                  default: it boots a Linux VM on every login whether or not you
                  use containers that session.
                '';
              };
            };
          };
        };
      };
    };
  };
}
