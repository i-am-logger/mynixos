{ activeUsers, config, lib, pkgs, ... }:

with lib;

{
  config = {
    home-manager.users = mapAttrs
      (_name: userCfg:
        mkIf userCfg.apps.dev.tools.githubDesktop.enable {
          home.packages = with pkgs; [
            github-desktop
          ];
        })
      (activeUsers config.my.users);
  };
}
