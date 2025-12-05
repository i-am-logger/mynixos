{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.my.apps.dev;
in
{
  config = mkIf cfg.direnv {
    home-manager.users = mapAttrs
      (name: userCfg: {
        programs.direnv = {
          enable = true;
          nix-direnv.enable = true;
        };
      })
      config.my.users;
  };
}
