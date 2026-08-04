# System options whose implementation is Linux-only.
#
# All four are consumed by ./default.nix (my/system/core), which platforms/linux.nix
# imports and platforms/darwin.nix does not. Declared here rather than in the
# central my/system/options.nix so that setting them on a Mac is "does not
# exist" rather than a silent no-op: macOS has no kernel to choose, no udev, no
# systemd, and dual-booting Windows is not a thing it does.
#
# Type-only: my/system/options.nix carries `default` and `description` for the
# `system` submodule, and only one declaration may.

{ lib, ... }:

{
  system = lib.mkOption {
    type = lib.types.submodule {
      options = {
        # Read by my/system/kernel: `nixpkgs.hostPlatform = mkDefault
        # cfg.architecture`. A hardware profile normally sets hostPlatform
        # directly, so this is the escape hatch for a host with no profile --
        # mkDefault, so the profile still wins.
        architecture = lib.mkOption {
          type = lib.types.nullOr (lib.types.enum [ "x86_64-linux" "aarch64-linux" ]);
          default = null;
          description = "System architecture. Null means the hardware profile decides.";
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
      };
    };
  };
}
