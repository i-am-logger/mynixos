{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.my.apps.fileUtils.lsd;
in
{
  # Option is declared in flake.nix
  config = mkIf cfg {
    home-manager.users = mapAttrs (name: userCfg: {
      programs.lsd = {
        enable = true;
        settings = {
          date = "+%y-%m-%d %H:%M:%S";
          indicators = true;
          recursion = {
            depth = 2;
          };
          sorting = {
            dir-grouping = "first";
          };
          symlink-arrow = "~>";
          header = true;
          color = {
            when = "auto";
          };
          icons = {
            when = "auto";
          };
          blocks = [ "permission" "user" "group" "size" "date" "name" ];
        };
      };
    }) config.my.users;
  };
}
