{ activeUsers, config, lib, pkgs, ... }:

with lib;

{
  config = {
    home-manager.users = mapAttrs
      (_name: userCfg:
        mkIf userCfg.apps.terminal.fileManagers.mc.enable {
          home.packages = with pkgs; [
            mc
          ];

          # Note: You'll need to copy the config files from /etc/nixos/home/cli/mc/config
          # to a suitable location in your mynixos repository and adjust the source path below
          # xdg.configFile."mc" = {
          #   source = ./config;  # Adjust path to your mc config location
          #   recursive = true;
          # };
        })
      (activeUsers config.my.users);
  };
}
