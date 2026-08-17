# mynixos Opinionated Defaults: user account, Linux
#
# zsh is the default login shell on every platform. Declared per platform so
# the answer can differ without a shared profile pinning one platform's
# choice onto both.
#
# Imported only by platforms/linux.nix.

{ lib, ... }:

{
  options.my.users = lib.mkOption {
    type = lib.types.attrsOf (lib.types.submodule {
      config.shell = lib.mkDefault "zsh";
    });
  };
}
