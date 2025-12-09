{ config, lib, pkgs, appHelpers, ... }:

with lib;

{
  config = {
    home-manager.users = mapAttrs
      (name: userCfg:
        mkIf (appHelpers.shouldEnable userCfg "tools" "devenv") {
          home.packages = with pkgs; [
            devenv
          ];
        })
      config.my.users;
  };
}
