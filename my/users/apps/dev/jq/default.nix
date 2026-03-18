{ activeUsers, config, lib, pkgs, ... }:

with lib;

{
  config = {
    home-manager.users = mapAttrs
      (_name: userCfg:
        mkIf userCfg.apps.dev.tools.jq.enable {
          home.packages = with pkgs; [
            jq
          ];
        })
      (activeUsers config.my.users);
  };
}
