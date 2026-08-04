# my.system.persistence -- impermanence's collection point.
#
# Declared beside the thing that consumes it: ./feature-aggregation.nix builds
# the aggregate and ./impermanence.nix turns it into environment.persistence.
# Both are Linux-only, and so is this -- macOS has no impermanence, nothing
# wipes the disk on reboot, and there is no state to declare surviving it.
#
# Modules that are themselves cross-platform therefore contribute to it from a
# Linux-only sibling (my/users/apps/*/linux.nix, my/secrets/linux.nix) rather
# than directly, so nothing writes an option that does not exist on darwin.
#
# Type-only: my/system/options.nix carries `default` and `description` for the
# `system` submodule, and only one declaration may.

{ lib, ... }:

{
  system = lib.mkOption {
    type = lib.types.submodule {
      options = {
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
