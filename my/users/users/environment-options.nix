{ lib, pkgs, config, ... }:

let
  # App submodule: supports { package, settings } OR bare package via coercion
  appSubmodule = lib.types.submodule {
    options = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable this application";
      };

      package = lib.mkOption {
        type = lib.types.package;
        description = "Application package";
      };

      settings = lib.mkOption {
        type = lib.types.attrs;
        default = { };
        description = "Application-specific settings (passed to home-manager)";
      };
    };
  };

  # Coerce bare package to app submodule
  coercedAppType = lib.types.coercedTo
    lib.types.package
    (pkg: { package = pkg; })
    appSubmodule;

  # Check if graphical is enabled for this user
  # NOTE: config here is the USER submodule config (my.users.<name>)
  isGraphical = config.graphical.enable or false;
in
{
  options.environment = lib.mkOption {
    description = "User environment configuration (applications and shell environment)";
    default = { };
    type = lib.types.submodule {
      options = {
        BROWSER = lib.mkOption {
          type = lib.types.nullOr coercedAppType;
          # Set opinionated default only when graphical.enable = true
          default = if isGraphical then {
            enable = true;
            package = pkgs.brave;
            settings = { };
          } else null;
          description = "Web browser (sets BROWSER environment variable). Opinionated default: brave when graphical.enable = true";
        };

        TERMINAL = lib.mkOption {
          type = lib.types.nullOr coercedAppType;
          default = if isGraphical then {
            enable = true;
            package = pkgs.wezterm;
            settings = { };
          } else null;
          description = "Terminal emulator (sets TERMINAL environment variable). Opinionated default: wezterm when graphical.enable = true";
        };

        EDITOR = lib.mkOption {
          type = lib.types.nullOr coercedAppType;
          default = if isGraphical then {
            enable = true;
            package = pkgs.helix;
            settings = { };
          } else null;
          description = "Text editor (sets EDITOR and VISUAL environment variables). Opinionated default: helix when graphical.enable = true";
        };

        SHELL = lib.mkOption {
          type = lib.types.nullOr coercedAppType;
          default = if isGraphical then {
            enable = true;
            package = pkgs.bashInteractive;
            settings = { };
          } else null;
          description = "Shell (sets SHELL environment variable). Opinionated default: bash when graphical.enable = true";
        };

        FILE_MANAGER = lib.mkOption {
          type = lib.types.nullOr coercedAppType;
          default = if isGraphical then {
            enable = true;
            package = pkgs.yazi;
            settings = { };
          } else null;
          description = "File manager (sets FILE_MANAGER environment variable). Opinionated default: yazi when graphical.enable = true";
        };

        # Non-standard env vars (lowercase for clarity that they're not standard)
        launcher = lib.mkOption {
          type = lib.types.nullOr coercedAppType;
          default = if isGraphical then {
            enable = true;
            package = pkgs.walker;
            settings = { };
          } else null;
          description = "Application launcher (no standard environment variable). Opinionated default: walker when graphical.enable = true";
        };

        multiplexer = lib.mkOption {
          type = lib.types.nullOr coercedAppType;
          default = if isGraphical then {
            enable = true;
            package = pkgs.zellij;
            settings = { };
          } else null;
          description = "Terminal multiplexer (no standard environment variable). Opinionated default: zellij when graphical.enable = true";
        };
      };
    };
  };
}
