{ lib, pkgs, ... }:

{
  environment = lib.mkOption {
    description = "Environment variables, XDG, locale, timezone";
    default = { };
    type = lib.types.submodule {
      options = {
        enable = lib.mkEnableOption "environment configuration (variables, XDG, locale)";

        editor = lib.mkOption {
          type = lib.types.package;
          default = pkgs.helix;
          description = "Default text editor package (mynixos default: helix)";
        };

        browser = lib.mkOption {
          type = lib.types.package;
          default = pkgs.brave;
          description = "Default web browser package (mynixos default: brave)";
        };

        displayManager = lib.mkOption {
          description = "Display manager configuration for graphical login";
          default = { };
          type = lib.types.submodule {
            options = {
              type = lib.mkOption {
                type = lib.types.enum [ "greetd" "gdm" "sddm" "lightdm" ];
                default = "greetd";
                description = "Which display manager to use (mynixos default: greetd)";
              };

              greetd = lib.mkOption {
                description = "greetd display manager configuration";
                default = { };
                type = lib.types.submodule {
                  options = {
                    settings = lib.mkOption {
                      type = lib.types.attrs;
                      default = {
                        default_session = {
                          command = "Hyprland";
                          user = "greeter";
                        };
                      };
                      description = "greetd settings (mynixos default: tuigreet with Hyprland)";
                    };
                  };
                };
              };

              gdm = lib.mkOption {
                description = "GDM display manager configuration";
                default = { };
                type = lib.types.submodule {
                  options = {
                    wayland = lib.mkOption {
                      type = lib.types.bool;
                      default = true;
                      description = "Enable Wayland support (mynixos default: true)";
                    };
                  };
                };
              };

              sddm = lib.mkOption {
                description = "SDDM display manager configuration";
                default = { };
                type = lib.types.submodule {
                  options = {
                    wayland = {
                      enable = lib.mkOption {
                        type = lib.types.bool;
                        default = true;
                        description = "Enable Wayland support (mynixos default: true)";
                      };
                    };
                  };
                };
              };

              lightdm = lib.mkOption {
                description = "LightDM display manager configuration";
                default = { };
                type = lib.types.submodule {
                  options = {
                    greeters = {
                      gtk = lib.mkOption {
                        type = lib.types.bool;
                        default = true;
                        description = "Use GTK greeter (mynixos default: true)";
                      };
                    };
                  };
                };
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
