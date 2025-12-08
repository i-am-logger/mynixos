{ config, lib, pkgs, ... }:

with lib;

{
  config = {
    home-manager.users = mapAttrs (name: userCfg:
      mkIf (userCfg.apps.terminal.multiplexers.zellij.enable or false) {
        programs.zellij = {
          enable = true;
          enableFishIntegration = false;
          enableBashIntegration = false;
          
          settings = {
            mouse_mode = true;
            copy_on_select = true;
            scrollback_editor = "hx";
            default_layout = "compact";
            
            ui = {
              pane_frames = {
                hide_session_name = false;
              };
            };
          };
        };
      }
    ) config.my.users;
  };
}
