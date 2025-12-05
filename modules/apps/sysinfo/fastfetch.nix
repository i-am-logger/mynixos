{ config, lib, pkgs, ... }:

with lib;

{
  config = {
    home-manager.users = mapAttrs
      (name: userCfg:
        mkIf userCfg.apps.sysinfo.fastfetch {
          home.packages = with pkgs; [
            fastfetch
          ];
        }
      )
      config.my.users;
  };
}
