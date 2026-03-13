{ config, lib, ... }:

with lib;

{
  config = {
    home-manager.users = mapAttrs
      (_name: userCfg:
        mkIf (userCfg.apps.dev.tools.direnv.enable or false) {
          programs.direnv = {
            enable = true;
            nix-direnv.enable = true;
          };
        })
      config.my.users;
  };
}
