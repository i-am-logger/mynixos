{ lib, ... }:

{
  environment = lib.mkOption {
    description = "Environment variables, XDG, locale, timezone";
    default = { };
    type = lib.types.submodule {
      options = {
        enable = lib.mkEnableOption "environment configuration (variables, XDG, locale)";


        editor = lib.mkOption {
          type = lib.types.nullOr lib.types.package;
          default = null;
          description = "Default text editor package (mynixos default: helix). Null means use the mynixos default.";
        };

        browser = lib.mkOption {
          type = lib.types.nullOr lib.types.package;
          default = null;
          description = "Default web browser package (mynixos default: brave). Null means use the mynixos default.";
        };

        # Graphical login as INTENT (mechanism vs look, typed) — the
        # my.environment.displayManager tree is hard-removed (repo policy:
        # no renames, no stubs). `backend` picks the display manager;
        # `look` picks the greeter surface: "vogix" = the vogix-themed SDDM
        # QML greeter under a Hyprland Lua compositor, and is SDDM-only
        # (asserted — there is no themed greetd greeter); "stock" = each
        # backend's own greeter (tuigreet for greetd). The vogix theming
        # module defaults backend/look to sddm/vogix when the theme system
        # is on; without it the default is greetd+stock (tuigreet — text,
        # minimal, never depends on the theme overlay).
        login = lib.mkOption {
          description = "Graphical login: which backend runs it, and how it looks";
          default = { };
          type = lib.types.submodule {
            options = {
              backend = lib.mkOption {
                type = lib.types.enum [ "sddm" "greetd" "gdm" "lightdm" ];
                default = "greetd";
                description = "Display manager running the login (mynixos default: greetd; the vogix theming module defaults it to sddm)";
              };

              look = lib.mkOption {
                type = lib.types.enum [ "vogix" "stock" ];
                default = "stock";
                description = "Greeter surface: vogix-themed (requires my.theming.vogix) or the backend's stock greeter";
              };

              session = lib.mkOption {
                type = lib.types.str;
                default = "hyprland";
                description = "Session name used for autologin's default session";
              };

              autologin = {
                enable = lib.mkEnableOption "automatic login (skips authentication — and any configured U2F key — at boot)";
                user = lib.mkOption {
                  type = lib.types.nullOr lib.types.str;
                  default = null;
                  description = "User logged in automatically";
                };
              };

              compositor = lib.mkOption {
                type = lib.types.enum [ "hyprland" "weston" ];
                default = "hyprland";
                description = "Compositor hosting SDDM's greeter (weston exists for VM tests; Hyprland needs GL)";
              };
            };
          };
        };

        timezone = lib.mkOption {
          type = lib.types.str;
          default = "America/Denver";
          description = "System timezone (mynixos default: America/Denver)";
        };

        locale = lib.mkOption {
          type = lib.types.str;
          default = "en_US.UTF-8";
          description = "System locale (mynixos default: en_US.UTF-8)";
        };

        keyboardLayout = lib.mkOption {
          type = lib.types.str;
          default = "us";
          description = "Keyboard layout (mynixos default: us)";
        };

        xdg = {
          enable = lib.mkEnableOption "XDG portal support for Wayland";
        };

        motd = lib.mkOption {
          description = "Message of the day configuration";
          default = { };
          type = lib.types.submodule {
            options = {
              enable = lib.mkEnableOption "message of the day";

              content = lib.mkOption {
                type = lib.types.str;
                default = "";
                description = "MOTD content to display on login";
              };
            };
          };
        };
      };
    };
  };
}
