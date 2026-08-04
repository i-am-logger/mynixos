# Persistence for this app, on Linux.
#
# `my.system.persistence.features` is impermanence's collection point and is
# declared only on Linux, so the write lives here rather than in ./default.nix,
# which platforms/common.nix imports for both platforms. macOS has no
# impermanence: nothing wipes the disk on reboot, so there is nothing to declare.
#
# Fleet-wide rather than per-user, because the app is chosen through a selector
# (environment.* / terminal.multiplexer) and so has no apps.* option to carry
# persistedDirectories. Brave's profile -- logins, cookies, extensions, history.
#
# Imported only by platforms/linux.nix.
{ activeUsers, config, lib, ... }:

with lib;

let
  isBrave = userCfg: let b = userCfg.environment.BROWSER; in b != null && b.enable && (b.package.pname or "") == "brave";
in
{
  config.my.system.persistence.features.userDirectories =
    optionals (any isBrave (attrValues (activeUsers config.my.users))) [ ".config/BraveSoftware" ];
}
