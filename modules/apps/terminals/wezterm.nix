{ config, lib, pkgs, ... }:

with lib;

in
{
  config = {
    home-manager.users = mapAttrs
      (name: userCfg:
        mkIf userCfg.apps.terminals.wezterm {
      programs.wezterm = {
        enable = true;
        enableBashIntegration = true;
        extraConfig = ''
          local wezterm = require 'wezterm'
          local config = wezterm.config_builder()

          -- Font settings
          config.font = wezterm.font('FiraCode Nerd Font')
          config.font_size = 24.0
          config.harfbuzz_features = { 'calt=1', 'clig=1', 'liga=1' }

          -- Terminal settings
          config.enable_wayland = true
          config.window_background_opacity = 0.70
          config.hide_tab_bar_if_only_one_tab = true
          config.default_cursor_style = 'BlinkingBlock'
          config.cursor_blink_rate = 200
          config.cursor_thickness = 1
          config.window_close_confirmation = 'NeverPrompt'
          config.term = 'xterm-256color'
          config.check_for_updates = false

          -- Selection behavior
          config.selection_word_boundary = ' \t\n{}"\'`,;:'

          return config
        '';
      };
        }
      )
      config.my.users;
  };
}
