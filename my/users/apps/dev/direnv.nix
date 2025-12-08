{ config, lib, pkgs, appHelpers, ... }:

with lib;

{
  config = {
    home-manager.users = mapAttrs
      (name: userCfg:
        mkIf (appHelpers.shouldEnable userCfg "dev" "direnv") {
          programs.direnv = {
          enable = true;
          nix-direnv.enable = true;
        };
      })
      config.my.users;
  };
}
