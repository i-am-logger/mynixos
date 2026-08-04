# 1Password option.
#
# Common, not platform-scoped: ./default.nix implements it on Linux and
# ./darwin.nix on macOS, so the option is meaningful on both and belongs
# wherever both implementations can see it.

{ lib, ... }:

let
  appLib = import ../../../../../lib/app-options.nix { inherit lib; };
in
{
  options.my.users = lib.mkOption {
    type = lib.types.attrsOf (lib.types.submodule {
      options.apps.security.passwords.onePassword = appLib.mkAppOption {
        name = "1Password";
        default = false;
        description = "1Password password manager";
        persistedDirectories = [ ".config/1Password" ];
      };
    });
  };
}
