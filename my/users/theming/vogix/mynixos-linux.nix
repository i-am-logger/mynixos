# mynixos Opinionated Defaults: Vogix Theming
#
# This file auto-enables vogix for all users by default
# Vogix themes terminal apps (btop, bat, ripgrep, alacritty) regardless of graphical environment
# Users can override by setting theming.vogix.enable = false

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
            theming.vogix.enable = lib.mkDefault true;
          };
        }
      )
    );
  };
}
