{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.my.apps.terminals;
in
{
  config = mkIf cfg.alacritty {
    home-manager.users = mapAttrs
      (name: userCfg: {
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
