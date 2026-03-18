{ activeUsers, config, lib, pkgs, ... }:

with lib;

{
  config = {
    home-manager.users = mapAttrs
      (_name: userCfg:
        mkIf userCfg.apps.terminal.network.termscp.enable {
          home.packages = with pkgs; [
            termscp
          ];
        })
      (activeUsers config.my.users);
  };
}
