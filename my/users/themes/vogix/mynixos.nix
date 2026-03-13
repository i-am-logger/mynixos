# mynixos Opinionated Defaults: Vogix Theming
#
# This file auto-enables vogix for all users by default
# Vogix themes terminal apps (btop, bat, ripgrep, alacritty) regardless of graphical environment
# Users can override by setting themes.vogix.enable = false

{ lib, ... }:

{
  # Inject opinionated defaults into user submodule
  options.my.users = lib.mkOption {
    type = lib.types.attrsOf (
      lib.types.submodule (
        _:
        {
          config = {
            # Enable vogix for all users by default
            themes.vogix.enable = lib.mkDefault true;
          };
        }
      )
    );
  };
}
