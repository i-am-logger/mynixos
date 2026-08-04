# mynixos Opinionated Defaults: Terminal Apps, darwin
#
# zsh is the macOS login shell -- Terminal.app, Setup Assistant and the dscl
# account defaults all assume it -- so it is on, matching the `shell` default in
# my/users/users/mynixos-darwin.nix.
#
# Imported only by platforms/darwin.nix.

{ lib, ... }:

{
  options.my.users = lib.mkOption {
    type = lib.types.attrsOf (lib.types.submodule ({ config, ... }: {
      config = lib.mkIf (config.terminal.enable or false) {
        apps.terminal.shells.zsh.enable = lib.mkDefault true;
      };
    }));
  };
}
