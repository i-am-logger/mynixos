{ config, lib, pkgs, appHelpers, ... }:

with lib;

{
  config = {
    home-manager.users = mapAttrs
      (name: userCfg:
        mkIf (appHelpers.shouldEnable userCfg "dev" "githubDesktop") {
          home.packages = with pkgs; [
            github-desktop
          ];
        })
      config.my.users;
  };
}
