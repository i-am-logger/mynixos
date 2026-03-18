{ activeUsers, config, lib, pkgs, ... }:

with lib;

{
  config = {
    home-manager.users = mapAttrs
      (_name: userCfg:
        mkIf userCfg.apps.dev.tools.kdiff3.enable {
          home.packages = with pkgs; [
            kdiff3
          ];
        })
      (activeUsers config.my.users);
  };
}
