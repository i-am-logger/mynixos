{ name, lib, pkgs, ... }:

{
  options = {
    name = lib.mkOption {
      type = lib.types.str;
      default = name;
      description = "Username";
    };

    fullName = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Full name for git, etc (required if user is fully managed by mynixos)";
    };

    description = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "User account description (displayed in login manager)";
    };

    email = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Email for git, etc (required for git configuration)";
    };

    shell = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Default shell (fish, bash, zsh)";
    };

    hashedPassword = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Hashed password for user account (DEPRECATED: use hashedPasswordFile instead for security)";
    };

    hashedPasswordFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = "Path to file containing hashed password (preferred over hashedPassword for security)";
    };

    secrets = lib.mkOption {
      type = lib.types.submodule {
        options = {
          hashedPassword = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = "Use sops secret for hashed password (requires my.secrets.enable = true). Secret path: users/<username>/password";
          };
        };
      };
      default = { };
      description = "Per-user secrets configuration (managed via sops-nix)";
    };

    packages = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = [ ];
      description = "User-specific packages";
    };

    avatar = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = "Path to user avatar/icon image (PNG recommended, will be set up for AccountsService)";
    };

    mounts = lib.mkOption {
      type = lib.types.listOf (lib.types.submodule {
        options = {
          mountPoint = lib.mkOption {
            type = lib.types.str;
            description = "Mount point path (relative to user home or absolute)";
          };

          device = lib.mkOption {
            type = lib.types.str;
            description = "Device path or UUID (will be prefixed with /dev/disk/by-uuid/ if not a full path)";
          };

          fsType = lib.mkOption {
            type = lib.types.str;
            default = "ext4";
            description = "Filesystem type";
          };

          options = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [ "defaults" ];
            description = "Mount options";
          };

          noCheck = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = "Skip filesystem check";
          };
        };
      });
      default = [ ];
      description = "User-specific filesystem mounts";
    };
  };
}
