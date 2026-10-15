# herdr-focus-notify, on macOS (./options-darwin.nix).
#
# Registered from its own activation entry, the same way ./default.nix
# registers the cross-platform plugins (./plugin-registry.nix), and unlinked
# when switched off. Its own herdr floor (0.7.5) is below the 0.9.1 that
# ./default.nix asserts once any plugin is on, so that floor is restated here
# for the case where this is the only one.
#
# Nothing here supplies `alerter`, which the plugin needs to show anything:
# nixpkgs has no alerter, and its build needs Swift tools 6.1 against
# nixpkgs' 5.10. `terminal-notifier` cannot stand in -- the click path
# depends on options and output only alerter has. Without it the plugin runs
# and every notification is dropped.
#
# Imported only by platforms/darwin.nix.
{ activeUsers, config, lib, pkgs, ... }:

with lib;

let
  isHerdr = userCfg: (userCfg.terminal.multiplexer or null) == "herdr";
  registry = import ./plugin-registry.nix { inherit lib pkgs; };
  focusNotify = pkgs.callPackage ../../../../../packages/herdr-focus-notify { };
in
{
  config = {
    assertions = concatLists (mapAttrsToList
      (name: userCfg:
        optional (isHerdr userCfg && userCfg.terminal.herdr.plugins.focusNotify.enable) {
          assertion = versionAtLeast pkgs.herdr.version "0.9.1";
          message = "my.users.${name}.terminal.herdr.plugins.focusNotify needs herdr >= 0.9.1; pkgs.herdr is ${pkgs.herdr.version}";
        })
      (activeUsers config.my.users));

    home-manager.users = mapAttrs
      (_name: userCfg:
        { lib, ... }@hm:
        let
          inherit (userCfg.terminal.herdr.plugins.focusNotify) enable;
        in
        lib.mkIf (isHerdr userCfg) (lib.mkMerge [
          {
            home.activation.herdrPluginsDarwin = lib.hm.dag.entryAfter [ "herdrPlugins" ] (registry.script {
              configHome = hm.config.xdg.configHome;
              stateHome = hm.config.xdg.stateHome;
              plugins = [{ id = focusNotify.pluginId; root = registry.rootOf focusNotify; inherit enable; }];
            });
          }
          (lib.mkIf enable {
            home.packages = [ focusNotify ];
          })
        ]))
      (activeUsers config.my.users);
  };
}
