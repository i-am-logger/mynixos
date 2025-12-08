{ config, lib, pkgs, ... }:

with lib;

{
  config = {
    home-manager.users = mapAttrs
      (name: userCfg:
        mkIf (userCfg.apps.graphical.terminals.kitty.enable or false) {
          home.packages = with pkgs; [
            kitty
          ];

          programs.kitty = {
            enable = true;
            settings = {
              # Window settings
              window_layouts = false;
              confirm_os_window_close = 0;
              resize_in_steps = false;
              
              # Bell settings
              enable_audio_bell = true;
              window_alert_on_bell = "yes";
              bell_on_tab = "🔔 ";
              
              # Cursor settings
              cursor_shape = "block";
              cursor_text_color = "background";
              cursor_blink_interval = 1;
              cursor_stop_blinking_after = 0;
              
              # Font settings
              disable_ligatures = "never";
              
              # URL handling
              open_url_with = "default";
              detect_urls = true;
              show_hyperlink_targets = true;
              underline_hyperlinks = "always";
              
              # Selection
              copy_on_select = true;
              
              # Scrolling
              wheel_scroll_multiplier = 5;
              touch_scroll_multiplier = 7;
              scrollback_lines = 100000;
              scrollback_pager = "hx";
              
              # Performance
              sync_to_monitor = true;
              
              # Transparency
              dim_opacity = 0;
            };
            
            keybindings = {
              # Font size controls
              "ctrl+shift+equal" = "change_font_size all +1.0";
              "ctrl+shift+plus" = "change_font_size all +1.0";
              "ctrl+shift+kp_add" = "change_font_size all +1.0";
              "ctrl+shift+minus" = "change_font_size all -1.0";
              "ctrl+shift+kp_subtract" = "change_font_size all -1.0";
              "ctrl+shift+backspace" = "change_font_size all 0";
              
              # URL hints
              "ctrl+shift+e" = "open_url_with_hints";
            };
          };
        })
      config.my.users;
  };
}
