# Persistence for this app, on Linux.
#
# `my.system.persistence.features` is impermanence's collection point and is
# declared only on Linux, so the write lives here rather than in ./default.nix,
# which platforms/common.nix imports for both platforms. macOS has no
# impermanence: nothing wipes the disk on reboot, so there is nothing to declare.
#
# Fleet-wide rather than per-user, because the app is chosen through a selector
# (terminal.multiplexer) and so has no apps.* option to carry
# persistedDirectories.
#
# Both directories are state, not config: .config/herdr holds session.json and
# session-history.json alongside the store-symlinked config.toml, and .herdr is
# the default worktree checkout root.
#
# Imported only by platforms/linux.nix.
{ activeUsers, config, lib, ... }:

with lib;

let
  isHerdr = userCfg: (userCfg.terminal.multiplexer or null) == "herdr";
in
{
  config.my.system.persistence.features.userDirectories =
    optionals (any isHerdr (attrValues (activeUsers config.my.users))) [ ".config/herdr" ".herdr" ];
}
