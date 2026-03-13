{ config, lib, ... }:

with lib;

{
  # Option is declared in flake.nix
  config = {
    home-manager.users = mapAttrs
      (_name: userCfg:
        mkIf (userCfg.apps.terminal.viewers.bat.enable or false) {
          programs.bat = {
            enable = true;
          };
        })
      config.my.users;
  };
}
