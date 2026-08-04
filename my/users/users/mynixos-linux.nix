# mynixos Opinionated Defaults: user account, Linux
#
# bash is the shell a NixOS account gets unless told otherwise, and it is the one
# every mynixos host has used. Stated here rather than in a shared profile so the
# answer can differ per platform without the profile pinning one platform's
# choice onto both.
#
# Imported only by platforms/linux.nix.

{ lib, ... }:

{
  options.my.users = lib.mkOption {
    type = lib.types.attrsOf (lib.types.submodule {
      config.shell = lib.mkDefault "bash";
    });
  };
}
