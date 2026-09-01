{ lib, ... }:

{
  dev = lib.mkOption {
    description = "Development tools (containers, binfmt, AppImage support)";
    default = { };
    type = lib.types.submodule {
      options = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Auto-set to true when any user has dev.enable = true (managed by mynixos)";
        };

        containers = lib.mkOption {
          description = ''
            Host-wide container settings. Whether containers are INSTALLED for a
            user is the per-user my.users.<n>.dev.containers.enable option; this
            is for settings that belong to the machine rather than the account.
          '';
          default = { };
          type = lib.types.submodule {
            options = {
              backend = lib.mkOption {
                type = lib.types.enum [ "podman" "docker" ];
                default = "podman";
                description = ''
                  Which container runtime the machine runs. This is an enum and
                  not two booleans because the two cannot coexist:
                  `virtualisation.podman.dockerCompat` and
                  `virtualisation.docker.enable` both claim the `docker` binary,
                  and `virtualisation.podman.dockerSocket.enable` and dockerd
                  both claim /run/docker.sock. nixpkgs asserts on the collision.

                  "podman" (the default): daemonless, rootless by default. No
                  account needs membership of a root-equivalent `docker` group,
                  which is the reason it is the default.

                  "docker": dockerd in rootless mode, for a host that needs
                  something podman genuinely cannot serve.

                  darwin runs containers in a Colima VM and implements only
                  "docker"; my/dev/containers/mynixos-darwin.nix sets the
                  default there, and my/dev/containers/default.nix rejects
                  "podman" rather than silently ignoring it.
                '';
              };

              autoStart = lib.mkOption {
                type = lib.types.bool;
                default = false;
                description = ''
                  darwin only: start the Colima VM at login via a launchd agent.
                  Off by default — it boots a Linux VM on every login whether or
                  not you use containers that session. Ignored on NixOS, which
                  runs podman (or dockerd) natively against the host kernel.
                '';
              };
            };
          };
        };
      };
    };
  };
}
