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
          description = "Kernel selection: override the packaged kernel set, or build boot.kernelPackages from a local source tree.";
          default = { };
          type = lib.types.submodule {
            options = {
              package = lib.mkOption {
                type = lib.types.nullOr lib.types.package;
                default = null;
                description = "Kernel packages override (e.g. pkgs.linuxPackages_latest, pkgs.linuxPackages_6_12). When set, assigned at normal priority so it overrides a hardware module's mkDefault kernel (a host mkForce still wins). If null (and localSource is unset) the mynixos default (linuxPackages_latest) is used at mkDefault, which hardware may override.";
              };

              localSource = lib.mkOption {
                default = null;
                description = "Build boot.kernelPackages from a local kernel source tree instead of a packaged kernel. Takes precedence over `package`. Intended for a checked-out git tree exposed as a `flake = false` git+file input (copies tracked files only). mynixos overrides a nixpkgs mainline kernel's src/version so NixOS kernel-config generation and boot.kernelPatches still apply to the source build.";
                type = lib.types.nullOr (lib.types.submodule {
                  options = {
                    src = lib.mkOption {
                      type = lib.types.path;
                      description = "Kernel source tree (must contain the top-level Makefile); e.g. the outPath of a `flake = false` source input.";
                    };
                    version = lib.mkOption {
                      type = lib.types.str;
                      description = "Upstream version of the tree, e.g. \"7.1.0\". MUST equal the tree's Makefile VERSION.PATCHLEVEL.SUBLEVEL, otherwise a /lib/modules modDirVersion mismatch hard-fails the build.";
                    };
                    modDirVersion = lib.mkOption {
                      type = lib.types.nullOr lib.types.str;
                      default = null;
                      description = "Module directory version = `make kernelrelease` = include/config/kernel.release. Defaults to `version`; set explicitly only if the tree appends a LOCALVERSION/`+` suffix.";
                    };
                    base = lib.mkOption {
                      type = lib.types.nullOr lib.types.package;
                      default = null;
                      description = "nixpkgs mainline kernel whose config baseline to override (e.g. pkgs.linux_7_1). Pin it to the source's series so a future nixpkgs `latest` bump does not shift the common-config baseline. If null, uses pkgs.linux_latest.";
                    };
                  };
                });
              };
            };
          };
        };

        architecture = lib.mkOption {
          type = lib.types.nullOr (lib.types.enum [ "x86_64-linux" "aarch64-linux" ]);
          default = null;
          description = "System architecture (auto-detected from hardware if null)";
        };

        enable = lib.mkEnableOption "core system utilities (console, nix, boot configuration, plymouth)";

        udev = {
          enable = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "Master switch for custom device udev rules. When false, sets all device udev options to false via mkDefault. Individual devices can override with mkForce.";
          };
        };

        dualBoot = {
          windows = lib.mkEnableOption "Windows dual-boot support (NTFS, local time clock)";
        };

        systemd = {
          enable = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "Master switch for mynixos-managed systemd configuration (journald, coredump). When false, the host keeps NixOS defaults.";
          };
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
