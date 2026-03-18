{ activeUsers, config, lib, pkgs, ... }:

with lib;

{
  config = {
    home-manager.users = mapAttrs
      (_name: userCfg:
        mkIf userCfg.apps.graphical.editors.marktext.enable {
          home.packages = with pkgs; [
            marktext
          ];
        })
      (activeUsers config.my.users);
  };
}
