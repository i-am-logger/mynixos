{ config, lib, pkgs, ... }:

with lib;

{
  config = {
    home-manager.users = mapAttrs
      (name: userCfg:
        mkIf userCfg.apps.terminals.ghostty {
      home.packages = with pkgs; [
        ghostty
      ];

      # Copy shader files from source
      # Note: You'll need to copy the shaders directory from /etc/nixos/home/gui/ghostty/shaders
      # to your theme or config location and adjust the source path below
      # xdg.configFile."ghostty/shaders/" = {
      #   source = ./shaders;  # Adjust path to your shaders location
      #   recursive = true;
      # };

      programs.ghostty = {
        enable = true;
        enableFishIntegration = false;
        enableBashIntegration = true;
        installBatSyntax = true;
        # settings reference  https://ghostty.org/docs/config/reference
        settings = {
          font-family = "FireCode Nerd Font";
          font-size = 24;
          font-thicken = true;
          term = "xterm-256color";
          auto-update-channel = "tip";
          background-opacity = 1.0;
          adjust-cell-width = 1;
          adjust-cell-height = 1;
          cursor-style = "block";
          cursor-style-blink = true;
          # window-decoration = false;
          confirm-close-surface = false;
          copy-on-select = true;
          # custom-shader = "shaders/in-game-crt.glsl";
          # custom-shader-animation = true;
        };
      };
        }
      )
      config.my.users;
  };
}
