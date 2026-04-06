{ activeUsers
, config
, lib
, pkgs
, ...
}:

with lib;

let
  bespec = pkgs.callPackage ../../../../../packages/bespec { };
in
{
  config = {
    home-manager.users = mapAttrs
      (
        _name: userCfg:
          let
            cfg = userCfg.apps.terminal.visualizers.bespec;
          in
          mkIf cfg.enable {
            home.packages = [ bespec ];
          }
      )
      (activeUsers config.my.users);
  };
}
