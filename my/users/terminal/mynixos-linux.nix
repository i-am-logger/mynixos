# mynixos Opinionated Defaults: Terminal Apps, Linux
#
# zsh is the login shell (my/users/users/mynixos-linux.nix), so its
# home-manager config is on by default.
#
# Imported only by platforms/linux.nix.

{ lib, ... }:

{
  options.my.users = lib.mkOption {
    type = lib.types.attrsOf (lib.types.submodule ({ config, ... }: {
      config = lib.mkIf (config.terminal.enable or false) {
        apps.terminal = {
          shells.zsh.enable = lib.mkDefault true;
        };
      };
    }));
  };
}
