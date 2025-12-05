{ config, lib, pkgs, ... }:

with lib;

{
  config = {
    home-manager.users = mapAttrs
      (name: userCfg:
        mkIf userCfg.apps.editors.marktext {
          home.packages = with pkgs; [
            marktext
          ];
        }
      )
      config.my.users;
  };
}
