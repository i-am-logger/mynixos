{ config, lib, pkgs, ... }:

with lib;

{
  config = {
    home-manager.users = mapAttrs
      (name: userCfg:
        {
          home.packages = with pkgs; [
            alacritty
          ];

          programs.alacritty = {
            enable = true;
          };
        })
      config.my.users;
  };
}
