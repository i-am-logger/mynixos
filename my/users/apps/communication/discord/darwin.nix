# Discord on macOS: a Homebrew cask, not the nixpkgs derivation.
#
# This is a deliberate exception to "everything else should be a derivation",
# and the reason is measurable rather than a matter of taste. nixpkgs stages
# Discord's fifteen native modules INSIDE the signed app bundle, at
# Contents/Resources/modules/. Those files were not present when Discord, Inc.
# signed and notarised the bundle, so the seal no longer holds:
#
#   $ codesign --verify --strict <store-path>/Applications/Discord.app
#   a sealed resource is missing or invalid
#   file added: .../Contents/Resources/modules/discord_rpc/index.js
#
# macOS then refuses to launch it outright -- "Discord is damaged and can't be
# opened" -- and, because the bundle has no valid identity, it also cannot be
# recognised as com.hnc.Discord for the purposes of reaching its own data in
# ~/Library/Application Support/discord, which macOS protects per-app.
#
# The CLI wrapper fails separately and for a related reason: it runs a
# pre-launch helper under a Nix-store python3, which is a different program
# reaching into another app's protected directory, so TCC denies it with EPERM.
# The wrapper is `bash -e`, so that non-zero exit aborts before the exec.
#
# None of this is fixable downstream: any modification to the bundle breaks the
# seal, and staging the modules is how the package works. The cask installs
# Discord's own signed, notarised build, which launches and keeps its identity.
#
# Only the INSTALL is managed. The cask is auto_updates, so Discord updates
# itself -- which is what it does regardless, and the reason nixpkgs carries a
# "disable breaking updates" patch at all.
#
# Imported only by platforms/darwin.nix.
{ config, lib, ... }:

with lib;

let
  anyUserDiscord = any
    (userCfg: userCfg.apps.communication.messaging.discord.enable or false)
    (attrValues config.my.users);
in
{
  config = mkIf anyUserDiscord {
    my.homebrew.casks = [ "discord" ];

    # Without Homebrew there is nothing to install into, and the app would just
    # silently not appear. Say so instead.
    assertions = [
      {
        assertion = config.my.homebrew.enable;
        message = ''
          my.users.<name>.apps.communication.messaging.discord is enabled, but
          my.homebrew.enable is false. Discord on darwin is a Homebrew cask --
          see my/users/apps/communication/discord/darwin.nix for why it cannot
          be the nixpkgs derivation.
        '';
      }
    ];
  };
}
