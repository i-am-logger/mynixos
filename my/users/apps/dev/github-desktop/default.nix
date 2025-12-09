{ config, lib, pkgs, appHelpers, ... }:

with lib;

{
  config = {
    home-manager.users = mapAttrs
      (name: userCfg:
        mkIf (appHelpers.shouldEnable userCfg "tools" "githubDesktop") {
          home.packages = with pkgs; [
            github-desktop
          ];
        })
      config.my.users;
  };
}
