{ config, lib, pkgs, ... }:

with lib;

{
  config = {
    home-manager.users = mapAttrs
      (name: userCfg:
        mkIf userCfg.apps.fileManagers.yazi {
          home.packages = with pkgs; [
            yazi
          ];

          programs.yazi = {
            enable = true;
            enableBashIntegration = true;
            enableFishIntegration = true;
            enableZshIntegration = true;
          };
        }
      )
      config.my.users;
  };
}
