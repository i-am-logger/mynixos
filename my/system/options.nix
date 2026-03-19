{ lib, ... }:

{
  system = lib.mkOption {
    description = "System-level configuration";
    default = { };
    type = lib.types.submodule {
      options = {
        hostname = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = "System hostname (if null, uses my.hostname for backwards compatibility)";
        };

        kernel = lib.mkOption {
          type = lib.types.nullOr lib.types.package;
          default = null;
          description = "Kernel package override (e.g., pkgs.linuxPackages_latest, pkgs.linuxPackages_6_12). If null, uses hardware module default (typically latest).";
        };

        architecture = lib.mkOption {
          type = lib.types.nullOr (lib.types.enum [ "x86_64-linux" "aarch64-linux" ]);
          default = null;
          description = "System architecture (auto-detected from hardware if null)";
        };

        enable = lib.mkEnableOption "core system utilities (console, nix, boot configuration, plymouth)";

        dualBoot = {
          windows = lib.mkEnableOption "Windows dual-boot support (NTFS, local time clock)";
        };

        allowedUnfreePackages = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          description = "List of unfree package names to allow. Modules append to this list and a single predicate is built centrally.";
        };

        persistence = lib.mkOption {
          description = "System persistence configuration";
          default = { };
          type = lib.types.submodule {
            options = {
              aggregated = lib.mkOption {
                type = lib.types.attrsOf (lib.types.submodule {
                  options = {
                    directories = lib.mkOption {
                      type = lib.types.listOf lib.types.nonEmptyStr;
                      description = "Aggregated directories to persist for this user";
                      readOnly = true;
                    };
                    files = lib.mkOption {
                      type = lib.types.listOf lib.types.nonEmptyStr;
                      description = "Aggregated files to persist for this user";
                      readOnly = true;
                    };
                    apps = lib.mkOption {
                      type = lib.types.listOf lib.types.nonEmptyStr;
                      description = "List of enabled and persisted apps for this user";
                      readOnly = true;
                    };
                  };
                });
                description = "Aggregated persistence data from user app configurations (read-only)";
                readOnly = true;
              };

              features = lib.mkOption {
                type = lib.types.submodule {
                  options = {
                    systemDirectories = lib.mkOption {
                      type = lib.types.listOf lib.types.nonEmptyStr;
                      default = [ ];
                      description = "Aggregated system directories from features";
                    };
                    userDirectories = lib.mkOption {
                      type = lib.types.listOf lib.types.nonEmptyStr;
                      default = [ ];
                      description = "Aggregated user directories from features (per-user)";
                    };
                    userFiles = lib.mkOption {
                      type = lib.types.listOf lib.types.nonEmptyStr;
                      default = [ ];
                      description = "Aggregated user files from features (per-user)";
                    };
                  };
                };
                default = { };
                description = "Aggregated persistence data from features";
              };
            };
          };
        };
      };
    };
  };
}
