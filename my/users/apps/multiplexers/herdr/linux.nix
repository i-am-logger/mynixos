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
# All state, not config: .config/herdr holds session.json, session-history.json
# and plugins.json (herdr's plugin registry, with each plugin's config under
# plugins/config) beside the store-symlinked config.toml, and .herdr is the
# default worktree checkout root. With any plugin on, .local/state/herdr holds
# each plugin's state directory (radar's agent-view switch, the usage
# monitor's cache). With herdr-projects on, ~/.herdr-projects holds every
# project, thread and inbox (its default root, src/paths.rs:93-94) and
# ~/.config/herdr-projects its profiles and safety settings
# (src/paths.rs:49-51).
#
# Imported only by platforms/linux.nix.
{ activeUsers, config, lib, ... }:

with lib;

let
  isHerdr = userCfg: (userCfg.terminal.multiplexer or null) == "herdr";
  plugins = userCfg: optionalAttrs (isHerdr userCfg) userCfg.terminal.herdr.plugins;
  anyPlugin = userCfg: any (p: p.enable or false) (attrValues (plugins userCfg));
  projectsOn = userCfg: (plugins userCfg).projects.enable or false;
  users = attrValues (activeUsers config.my.users);
in
{
  config.my.system.persistence.features.userDirectories =
    optionals (any isHerdr users) [ ".config/herdr" ".herdr" ]
    ++ optionals (any anyPlugin users) [ ".local/state/herdr" ]
    ++ optionals (any projectsOn users) [ ".herdr-projects" ".config/herdr-projects" ];
}
