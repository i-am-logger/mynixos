{ config, lib, pkgs, ... }:

with lib;

{
  config = {
    home-manager.users = mapAttrs
      (name: userCfg:
        mkIf (userCfg.apps.terminal.sysinfo.fastfetch.enable or false) {
          home.packages = with pkgs; [
            fastfetch
          ];
        })
      config.my.users;
  };
}
