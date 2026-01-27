# Unified themes options
# Defines my.themes.* with stylix and vogix as submodules
{ lib, pkgs, ... }:

{
  themes = lib.mkOption {
    description = "Theming configuration";
    default = { };
    type = lib.types.submodule {
      options = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Enable theming system (defaults to vogix)";
        };

        # Vogix runtime theme management
        vogix = lib.mkOption {
          description = "Vogix runtime theme management configuration";
          default = { };
          type = lib.types.submodule {
            options = {
              enable = lib.mkOption {
                type = lib.types.bool;
                default = true;
                description = "Enable vogix runtime theme management (default when themes.enable = true)";
              };
            };
          };
        };

        # Stylix static theming (legacy, disabled by default)
        stylix = lib.mkOption {
          description = "Stylix static theming configuration (legacy)";
          default = { };
          type = lib.types.submodule {
            options = {
              enable = lib.mkEnableOption "stylix static theming";

              type = lib.mkOption {
                type = lib.types.nullOr (lib.types.enum [ "stylix" ]);
                default = null;
                description = "Theme system type (deprecated)";
              };

              config = lib.mkOption {
                type = lib.types.nullOr lib.types.path;
                default = null;
                description = "Path to theme configuration file (e.g., stylix.nix)";
              };

              polarity = lib.mkOption {
                type = lib.types.enum [
                  "light"
                  "dark"
                ];
                default = "dark";
                description = "Color scheme polarity";
              };

              wallpaper = lib.mkOption {
                type = lib.types.nullOr lib.types.path;
                default = null;
                description = "Path to wallpaper image";
              };

              colorScheme = lib.mkOption {
                type = lib.types.nullOr lib.types.path;
                default = null;
                description = "Path to base16 YAML color scheme";
              };

              opacity = lib.mkOption {
                type = lib.types.submodule {
                  options = {
                    applications = lib.mkOption {
                      type = lib.types.float;
                      default = 0.95;
                      description = "Opacity for applications (0.0-1.0)";
                    };
                    desktop = lib.mkOption {
                      type = lib.types.float;
                      default = 0.95;
                      description = "Opacity for desktop (0.0-1.0)";
                    };
                    popups = lib.mkOption {
                      type = lib.types.float;
                      default = 0.95;
                      description = "Opacity for popups (0.0-1.0)";
                    };
                    terminal = lib.mkOption {
                      type = lib.types.float;
                      default = 0.95;
                      description = "Opacity for terminal (0.0-1.0)";
                    };
                  };
                };
                default = { };
                description = "Opacity settings for different UI elements";
              };

              fonts = lib.mkOption {
                type = lib.types.submodule {
                  options = {
                    sizes = lib.mkOption {
                      type = lib.types.submodule {
                        options = {
                          applications = lib.mkOption {
                            type = lib.types.int;
                            default = 28;
                            description = "Font size for applications";
                          };
                          desktop = lib.mkOption {
                            type = lib.types.int;
                            default = 32;
                            description = "Font size for desktop";
                          };
                          popups = lib.mkOption {
                            type = lib.types.int;
                            default = 28;
                            description = "Font size for popups";
                          };
                          terminal = lib.mkOption {
                            type = lib.types.int;
                            default = 32;
                            description = "Font size for terminal";
                          };
                        };
                      };
                      default = { };
                      description = "Font sizes for different UI elements";
                    };

                    serif = lib.mkOption {
                      type = lib.types.submodule {
                        options = {
                          name = lib.mkOption {
                            type = lib.types.str;
                            default = "Noto Nerd Font";
                            description = "Serif font name";
                          };
                          package = lib.mkOption {
                            type = lib.types.package;
                            default = pkgs.nerd-fonts.noto;
                            description = "Serif font package";
                          };
                        };
                      };
                      default = { };
                      description = "Serif font configuration";
                    };

                    sansSerif = lib.mkOption {
                      type = lib.types.submodule {
                        options = {
                          name = lib.mkOption {
                            type = lib.types.str;
                            default = "FiraCode Nerd Font";
                            description = "Sans-serif font name";
                          };
                          package = lib.mkOption {
                            type = lib.types.package;
                            default = pkgs.nerd-fonts.fira-code;
                            description = "Sans-serif font package";
                          };
                        };
                      };
                      default = { };
                      description = "Sans-serif font configuration";
                    };

                    monospace = lib.mkOption {
                      type = lib.types.submodule {
                        options = {
                          name = lib.mkOption {
                            type = lib.types.str;
                            default = "FiraCode Nerd Font";
                            description = "Monospace font name";
                          };
                          package = lib.mkOption {
                            type = lib.types.package;
                            default = pkgs.nerd-fonts.fira-code;
                            description = "Monospace font package";
                          };
                        };
                      };
                      default = { };
                      description = "Monospace font configuration";
                    };

                    emoji = lib.mkOption {
                      type = lib.types.submodule {
                        options = {
                          name = lib.mkOption {
                            type = lib.types.str;
                            default = "Noto Color Emoji";
                            description = "Emoji font name";
                          };
                          package = lib.mkOption {
                            type = lib.types.package;
                            default = pkgs.noto-fonts-color-emoji;
                            description = "Emoji font package";
                          };
                        };
                      };
                      default = { };
                      description = "Emoji font configuration";
                    };
                  };
                };
                default = { };
                description = "Font configuration";
              };

              cursor = lib.mkOption {
                type = lib.types.submodule {
                  options = {
                    name = lib.mkOption {
                      type = lib.types.str;
                      default = "Bibata-Modern-Amber";
                      description = "Cursor theme name";
                    };
                    package = lib.mkOption {
                      type = lib.types.package;
                      default = pkgs.bibata-cursors;
                      description = "Cursor theme package";
                    };
                    size = lib.mkOption {
                      type = lib.types.int;
                      default = 24;
                      description = "Cursor size";
                    };
                  };
                };
                default = { };
                description = "Cursor theme configuration";
              };
            };
          };
        };
      };
    };
  };
}
