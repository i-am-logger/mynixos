{ config, lib, pkgs, ... }:

with lib;

{
  config = {
    home-manager.users = mapAttrs
      (name: userCfg:
        mkIf userCfg.apps.browsers.firefox {
          programs.firefox = {
            enable = true;
            package = pkgs.firefox;
          };
        }
      )
      config.my.users;
  };
}
