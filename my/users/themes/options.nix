# Per-user vogix options
# Defines my.users.<name>.themes.vogix.* options
{ lib, ... }:

{
  options.themes = lib.mkOption {
    description = "Theme configuration for this user";
    default = { };
    type = lib.types.submodule {
      options = {
        vogix = lib.mkOption {
          description = "Vogix runtime theme management configuration";
          default = { };
          type = lib.types.submodule {
            options = {
              enable = lib.mkEnableOption "vogix runtime theme management for this user";

              scheme = lib.mkOption {
                type = lib.types.str;
                default = "vogix16";
                description = "Color scheme to use (vogix16, base16, base24, ansi16)";
              };

              theme = lib.mkOption {
                type = lib.types.str;
                default = "aikido";
                description = "Theme to use (vogix default: aikido)";
              };

              variant = lib.mkOption {
                type = lib.types.str;
                default = "night";
                description = "Variant (e.g., night, day, dark, light, mocha, latte)";
              };
            };
          };
        };
      };
    };
  };
}
