{ lib, ... }:

{
  storage = lib.mkOption {
    description = "Storage and filesystem configuration (disko + impermanence)";
    default = { };
    type = lib.types.submodule {
      options = {
        impermanence = lib.mkOption {
          description = "Tmpfs root with persistent storage";
          default = { };
          type = lib.types.submodule {
            options = {
              enable = lib.mkEnableOption "impermanence with opinionated defaults";

              persistPath = lib.mkOption {
                type = lib.types.nonEmptyStr;
                default = "/persist";
                description = "Path to persistent storage directory (must be an absolute path)";
              };

              useDedicatedPartition = lib.mkOption {
                type = lib.types.bool;
                default = true;
                description = "Use dedicated partition for persistent storage (vs tmpfiles)";
              };

              cloneFlakeRepo = lib.mkOption {
                type = lib.types.nullOr lib.types.nonEmptyStr;
                default = null;
                description = "Git URL to clone into /etc/nixos on first boot";
              };

              symlinkFlakeToHome = lib.mkOption {
                type = lib.types.bool;
                default = false;
                description = "Create a ~/.flake symlink to /etc/nixos for all users (auto-detected from my.users). Deliberately NOT wired to my.system.flakeDir — see the comment in my/storage/impermanence/impermanence.nix.";
              };

              extraSystemDirectories = lib.mkOption {
                type = lib.types.listOf lib.types.nonEmptyStr;
                default = [ ];
                description = "Additional system directories to persist";
              };

              extraUserDirectories = lib.mkOption {
                type = lib.types.listOf lib.types.nonEmptyStr;
                default = [ ];
                description = ''
                  Additional user directories to persist, applied to EVERY user on
                  the host. For one person's own folders use
                  `my.users.<name>.persistedDirectories` instead; for a piece of
                  software's state, declare it in that software's module.
                '';
              };

              extraUserFiles = lib.mkOption {
                type = lib.types.listOf lib.types.nonEmptyStr;
                default = [ ];
                description = "Additional user files to persist (applied to all users)";
              };

              enableCcache = lib.mkOption {
                type = lib.types.bool;
                default = true;
                description = "Enable ccache with bind-mount from persist to /tmp/ccache";
              };
            };
          };
        };
      };
    };
  };
}
