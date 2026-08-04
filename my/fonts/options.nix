{ lib, ... }:

{
  fonts = lib.mkOption {
    type = lib.types.submodule {
      options = {
        packages = lib.mkOption {
          type = lib.types.listOf lib.types.package;
          default = [ ];
          example = lib.literalExpression "[ pkgs.nerd-fonts.jetbrains-mono ]";
          description = ''
            Fonts installed system-wide. Empty means "use the mynixos default",
            which is a Nerd Font: waybar, starship and the shell prompts all draw
            glyphs from the Nerd Font private-use range and render boxes without
            one. Setting this REPLACES the default rather than adding to it.
          '';
        };
      };
    };
    default = { };
    description = "System fonts";
  };
}
