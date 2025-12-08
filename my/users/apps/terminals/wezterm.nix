{ config, lib, pkgs, ... }:

with lib;

{
  config = {
    home-manager.users = mapAttrs
      (name: userCfg:
        let
          terminal = userCfg.environment.TERMINAL;
          isGraphical = userCfg.graphical.enable or false;
          # Enable wezterm when:
          # 1. User explicitly set TERMINAL to wezterm, OR
          # 2. User has graphical.enable = true AND didn't set TERMINAL (opinionated default)
          hasWezterm =
            if terminal != null then
              terminal.enable && (terminal.package.pname or "") == "wezterm"
            else
              isGraphical; # Opinionated default: wezterm when graphical enabled and no terminal specified
          # Get package: from user config if set, otherwise use pkgs.wezterm
          weztermPackage = if terminal != null then terminal.package else pkgs.wezterm;
          # Get settings: from user config if set, otherwise empty
          weztermSettings = if terminal != null then terminal.settings else { };
        in
        mkIf hasWezterm {
          programs.wezterm = mkMerge [
            {
              enable = true;
              package = weztermPackage;
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
            }
            # Merge settings if provided
            weztermSettings
          ];
        }
      )
      config.my.users;
  };
}
