{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.my.apps.terminals.kitty;

  kittyConf = ''
    window_layouts = false
    confirm_os_window_close           0
    enable_audio_bell                 true
    window_alert_on_bell              yes
    bell_on_tab                       "🔔 "
    #allow_remote_control             true
    #window_padding_width              2
    disable_ligatures                 never
    cursor_shape                      block
    cursor_stop_blinking_after        0
    open_url_with                     default
    detect_urls                       yes
    show_hyperlink_targets            yes
    copy_on_select                    yes
    dim_opacity                       0
    wheel_scroll_multiplier           5
    underline_hyperlinks              always
    sync_to_monitor                   yes
    resize_in_steps                   no
    #term                              xterm-kitty

    map ctrl+shift+equal change_font_size all +1.0
    map ctrl+shift+plus change_font_size all +1.0
    map ctrl+shift+kp_add change_font_size all +1.0

    map ctrl+shift+minus change_font_size all -1.0
    map ctrl+shift+kp_subtract change_font_size all -1.0
    map ctrl+shift+backspace change_font_size all 0
    map ctrl+shift+e open_url_with_hints
  '';
in
{
  config = {
    home-manager.users = mapAttrs
      (name: userCfg:
        mkIf userCfg.apps.terminals.kitty {
          home.packages = with pkgs; [
            kitty
          ];

          programs.kitty = {
            enable = true;
            settings = {
              confirm_os_window_close = 0;
              enable_audio_bell = true;
              window_alert_on_bell = " yes";
              bell_on_tab = "🔔 ";
              disable_ligatures = "auto";
              cursor_text_color = "background";
              cursor_shape = "block";
              cursor_blink_internal = 1;
              cursor_stop_blinking_after = 0;
              detect_urls = "yes";
              show_hyperlink_targets = "yes";
              copy_on_select = "yes";
              dim_opacity = 0;
              touch_scroll_multiplier = 7;
              scrollback_lines = 100000;
              scrollback_pager = "hx";
              sync_to_monitor = "yes";
            };
          };

          # Additional kitty config file
          xdg.configFile."kitty/kitty.conf".text = kittyConf;
        }
      )
      config.my.users;
  };
}
