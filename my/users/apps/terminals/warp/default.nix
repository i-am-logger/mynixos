{ config, lib, pkgs, ... }:

with lib;

{
  config = {
    home-manager.users = mapAttrs
      (name: userCfg: {
        home.packages = with pkgs; [
          warp-terminal
        ];
      })
      config.my.users;
  };
}
