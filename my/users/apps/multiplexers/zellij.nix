{ config, lib, pkgs, ... }:

with lib;

{
  config = {
    home-manager.users = mapAttrs
      (name: userCfg:
        mkIf userCfg.apps.multiplexers.zellij {
          programs.zellij = {
            enable = true;
            enableFishIntegration = false;
            enableBashIntegration = false;
            # config = {
            # map-syntax = [ "*.conf:XML" ];
            # };

            # TODO: settings from ~/.config/zellij
            # settings = {
            #   mouse_mode = true;
            #   copy_on_select = true;
            #   scrollback_editor = "hx";
            #   ui.pane_frames.hide_session_name = false;

            # };
          };
        }
      )
      config.my.users;
  };
}
