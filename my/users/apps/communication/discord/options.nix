# Discord's option, declared beside its implementation rather than carried in a
# mkApp spec -- because there are two implementations and neither can own an
# option the other platform also needs: ./default.nix installs the nixpkgs
# derivation on Linux, ./darwin.nix declares a Homebrew cask on macOS. Same
# shape, and the same reason, as my/users/apps/security/1password/options.nix.
{ lib, ... }:

let
  appLib = import ../../../../../lib/app-options.nix { inherit lib; };
in
{
  options.my.users = lib.mkOption {
    type = lib.types.attrsOf (lib.types.submodule {
      options.apps.communication.messaging.discord = appLib.mkAppOption {
        name = "Discord";
        default = false;
        description = "Discord voice and text chat";
        # Linux only in effect: macOS keeps its state in
        # ~/Library/Application Support/discord, and no darwin host runs
        # impermanence.
        persistedDirectories = [ ".config/discord" ];
      };
    });
  };
}
