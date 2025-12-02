{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.my.apps.fileManagers;
in
{
  config = mkIf cfg.yazi {
    home-manager.users = mapAttrs (name: userCfg: {
      home.packages = with pkgs; [
        yazi
      ];

      programs.yazi = {
        enable = true;
        enableBashIntegration = true;
        enableFishIntegration = true;
        enableZshIntegration = true;
      };
    }) config.my.users;
  };
}
