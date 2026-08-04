# mynixos Opinionated Defaults: user account, darwin
#
# zsh is the macOS login shell. Aqua, Terminal.app and the account defaults macOS
# creates all assume it, so a configuration that says otherwise is asserting
# something the machine will not honour.
#
# mkDefault, so a person who genuinely wants a different shell everywhere states
# it once in their profile and it applies on both platforms.
#
# Imported only by platforms/darwin.nix, so it needs no isDarwin test.

{ lib, ... }:

{
  options.my.users = lib.mkOption {
    type = lib.types.attrsOf (lib.types.submodule {
      config.shell = lib.mkDefault "zsh";
    });
  };
}
