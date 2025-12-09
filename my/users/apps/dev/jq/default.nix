{ config, lib, pkgs, appHelpers, ... }:

with lib;

{
  config = {
    home-manager.users = mapAttrs
      (name: userCfg:
        mkIf (appHelpers.shouldEnable userCfg "tools" "jq") {
          home.packages = with pkgs; [
            jq
          ];
        })
      config.my.users;
  };
}
