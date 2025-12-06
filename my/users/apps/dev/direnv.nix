{ config, lib, pkgs, ... }:

with lib;

{
  config = {
    home-manager.users = mapAttrs
      (name: userCfg: mkIf userCfg.apps.dev.direnv {
        programs.direnv = {
          enable = true;
          nix-direnv.enable = true;
        };
      })
      config.my.users;
  };
}
