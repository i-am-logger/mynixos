{ config, lib, pkgs, ... }:

with lib;

{
  # Option is declared in flake.nix
  config = {
    home-manager.users = mapAttrs
      (name: userCfg:
        mkIf userCfg.apps.viewers.bat {
          programs.bat = {
            enable = true;
          };
        }
      )
      config.my.users;
  };
}
