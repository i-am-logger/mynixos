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
                type = lib.types.str;
                default = "/persist";
                description = "Path to persistent storage directory";
              };

              useDedicatedPartition = lib.mkOption {
                type = lib.types.bool;
                default = true;
                description = "Use dedicated partition for persistent storage (vs tmpfiles)";
              };

              persistUserData = lib.mkOption {
                type = lib.types.bool;
                default = true;
                description = "Persist user data directories (Media, Code)";
              };

              cloneFlakeRepo = lib.mkOption {
                type = lib.types.nullOr lib.types.str;
                default = null;
                description = "Git URL to clone into /etc/nixos on first boot";
              };

              symlinkFlakeToHome = lib.mkOption {
                type = lib.types.bool;
                default = false;
                description = "Create ~/.flake symlink pointing to /etc/nixos for all users (auto-detected from my.users)";
              };

              extraSystemDirectories = lib.mkOption {
                type = lib.types.listOf lib.types.str;
                default = [ ];
                description = "Additional system directories to persist";
              };

              extraUserDirectories = lib.mkOption {
                type = lib.types.listOf lib.types.str;
                default = [ ];
                description = "Additional user directories to persist (applied to all users)";
              };

              extraUserFiles = lib.mkOption {
                type = lib.types.listOf lib.types.str;
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
