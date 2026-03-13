{ config, lib, ... }:

with lib;

{
  # Option is declared in flake.nix
  config = {
    home-manager.users = mapAttrs
      (_name: userCfg:
        mkIf userCfg.apps.terminal.fileUtils.lsd.enable {
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
        })
      config.my.users;
  };
}
