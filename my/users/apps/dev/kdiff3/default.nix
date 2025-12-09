{ config, lib, pkgs, appHelpers, ... }:

with lib;

{
  config = {
    home-manager.users = mapAttrs
      (name: userCfg:
        mkIf (appHelpers.shouldEnable userCfg "tools" "kdiff3") {
          home.packages = with pkgs; [
            kdiff3
          ];
        })
      config.my.users;
  };
}
