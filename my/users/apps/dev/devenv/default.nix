{ activeUsers, config, lib, pkgs, ... }:

with lib;

{
  config = {
    home-manager.users = mapAttrs
      (_name: userCfg:
        mkIf userCfg.apps.dev.tools.devenv.enable {
          home.packages = with pkgs; [
            devenv
          ];
        })
      (activeUsers config.my.users);
  };
}
