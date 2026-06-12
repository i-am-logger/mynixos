# Per-user vogix options
# Defines my.users.<name>.theming.vogix.* options
{ lib, ... }:

{
  options.theming = lib.mkOption {
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

              # NOTE: scheme / theme / variant are intentionally free-form strings,
              # NOT enums. vogix discovers all three dynamically (builtins.readDir
              # over its flake inputs: vogix16-themes, tinted-schemes base16/base24,
              # iterm2 ansi16 — hundreds of themes, dozens of variants). vogix's own
              # option types these as `str`; constraining them here would be stricter
              # than vogix itself and reject valid values.

              scheme = lib.mkOption {
                type = lib.types.str;
                default = "vogix16";
                description = "Color scheme family (e.g. vogix16, base16, base24, ansi16)";
              };

              theme = lib.mkOption {
                type = lib.types.str;
                default = "yoga";
                description = "Theme name within the scheme (vogix default: yoga)";
              };

              variant = lib.mkOption {
                type = lib.types.str;
                default = "night";
                description = "Theme variant (vogix16 uses day/night; base16/base24 add many more)";
              };
            };
          };
        };
      };
    };
  };
}
