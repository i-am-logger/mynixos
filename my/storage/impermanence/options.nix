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

let
  # A persisted system directory with its owner, group and mode.
  # impermanence creates a missing persistent copy with them during
  # activation, and the bind mount shows that copy in place of the directory
  # tmpfiles or a service created. A path alone is root:root 0755.
  ownedDirectory = lib.types.submodule {
    options = {
      directory = lib.mkOption {
        type = lib.types.strMatching "/.+";
        description = "Absolute path of the directory.";
      };
      user = lib.mkOption {
        type = lib.types.nonEmptyStr;
        default = "root";
        description = "Owner of the persistent copy.";
      };
      group = lib.mkOption {
        type = lib.types.nonEmptyStr;
        default = "root";
        description = "Group of the persistent copy.";
      };
      mode = lib.mkOption {
        type = lib.types.strMatching "[0-7]{3,4}";
        default = "0755";
        description = "Mode of the persistent copy, in octal.";
      };
    };
  };
in
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
                      type = lib.types.listOf (lib.types.either lib.types.nonEmptyStr ownedDirectory);
                      default = [ ];
                      description = ''
                        Aggregated system directories from features: a path,
                        persisted as root:root 0755, or
                        `{ directory; user; group; mode; }` for a directory
                        that tmpfiles or a service gives another owner or
                        mode, so that its persistent copy is created with
                        them.
                      '';
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
