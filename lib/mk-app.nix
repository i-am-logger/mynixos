# mkApp — collapse the repeated per-user "enable an app via home-manager"
# boilerplate shared by the simple app modules under my/users/apps/.
#
# Usage (in an app's default.nix):
#
#   { mkApp, ... } @ args:
#   mkApp args {
#     path = "graphical.terminals.alacritty";          # under userCfg.apps
#     home = { ... }: { programs.alacritty.enable = true; };
#   }
#
# Spec fields:
#   path   : dotted path under `userCfg.apps` to the app submodule. The submodule
#            must expose `.enable`. e.g. "graphical.terminals.alacritty".
#   home   : function producing the per-user home-manager config. It receives the
#            full module-args set extended with { cfg, userCfg, name } where `cfg`
#            is the app submodule located at `path`. Defaults to producing {}.
#   unfree : optional list of package names added to
#            `my.system.allowedUnfreePackages` when ANY user enables the app.
#
# App modules import this file directly (relative path) and call it with their
# module args: `(import .../lib/mk-app.nix).mkApp args { ... }`. It is deliberately
# NOT delivered via _module.args — doing so caused infinite recursion, because an
# app module's return value *is* `mkApp args {...}`, forcing mkApp at module
# structure time, and resolving _module.args.mkApp requires the full config.
# For the same reason mkApp self-computes `activeUsers` from config instead of
# taking the `activeUsers` _module.arg (which would force app modules to name an
# otherwise-unused argument).
{
  mkApp = moduleArgs@{ config, lib, ... }: spec:
    let
      inherit (lib) mapAttrs mkIf mkMerge attrByPath splitString any attrValues;

      activeUsers = import ./active-users.nix lib;

      pathList = splitString "." spec.path;
      getCfg = userCfg:
        attrByPath pathList
          (throw "mkApp: no app option at userCfg.apps.${spec.path}")
          userCfg.apps;

      home = spec.home or (_: { });
      unfree = spec.unfree or [ ];

      perUser = mapAttrs
        (name: userCfg:
          let cfg = getCfg userCfg;
          in mkIf cfg.enable (home (moduleArgs // { inherit cfg userCfg name; })))
        (activeUsers config.my.users);

      anyEnabled = any
        (userCfg: (getCfg userCfg).enable or false)
        (attrValues config.my.users);
    in
    {
      config =
        if unfree == [ ] then {
          home-manager.users = perUser;
        } else
          mkMerge [
            (mkIf anyEnabled { my.system.allowedUnfreePackages = unfree; })
            { home-manager.users = perUser; }
          ];
    };
}
