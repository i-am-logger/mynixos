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
        { config, ... }:
        {
          config = {
            # Enable vogix for all users by default
            theming.vogix.enable = lib.mkDefault true;

            # baud takes its colours from its config.toml, which vogix's
            # palette links reach only through the baud module, so a
            # graphical vogix user gets it on: baud's colours match the
            # theme wherever baud is run. It installs no package.
            apps.graphical.terminals.baud.enable = lib.mkDefault
              (config.graphical.enable && config.theming.vogix.enable);
          };
        }
      )
    );
  };
}
