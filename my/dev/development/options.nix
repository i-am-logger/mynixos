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
          description = "Auto-set to true when any user has dev.enable = true (managed by mynixos)";
        };

        docker = lib.mkOption {
          description = ''
            Host-wide Docker settings. Whether Docker is INSTALLED for a user is
            the per-user my.users.<n>.dev.docker.enable option; this is for
            settings that belong to the machine rather than the account.
          '';
          default = { };
          type = lib.types.submodule {
            options = {
              autoStart = lib.mkOption {
                type = lib.types.bool;
                default = false;
                description = ''
                  darwin only: start the Colima VM at login via a launchd agent.
                  Off by default — it boots a Linux VM on every login whether or
                  not you use containers that session. Ignored on NixOS, which
                  runs dockerd natively via virtualisation.docker.
                '';
              };
            };
          };
        };
      };
    };
  };
}
