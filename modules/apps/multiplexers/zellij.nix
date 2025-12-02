{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.my.apps.multiplexers.zellij;
in
{

  config = mkIf cfg {
    home-manager.users = mapAttrs (name: userCfg: {
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
    }) config.my.users;
  };
}
