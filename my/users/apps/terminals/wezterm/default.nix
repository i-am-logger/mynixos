{ activeUsers, config, lib, pkgs, ... }:

with lib;

let
  # Same option on both platforms, different interior: the module is shared, so
  # the platform is read here rather than expressed by file placement.
  inherit (pkgs.stdenv.hostPlatform) isDarwin;
in
{
  config = {

    home-manager.users = mapAttrs
      (_name: userCfg:
        let
          terminal = userCfg.environment.TERMINAL;
          isGraphical = userCfg.graphical.enable;
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
                local config = wezterm.config_builder()

                -- Font settings
                config.font = wezterm.font('FiraCode Nerd Font')
                config.font_size = 24.0
                config.harfbuzz_features = { 'calt=1', 'clig=1', 'liga=1' }

                -- Terminal settings
                config.enable_wayland = true

                -- Transparency is only legible when something blurs what shows
                -- through. On Linux the compositor does that pass, so 0.70 reads
                -- as depth rather than as see-through.
                --
                -- macOS has no equivalent. wezterm draws its own surface with
                -- wgpu and adopts no AppKit materials, so the system Liquid Glass
                -- look is not available to it, and macos_window_background_blur
                -- -- the only native blur it exposes -- was not enough at any
                -- setting: 0.70 still read as plain see-through over whatever
                -- happened to be behind the window. Opaque there instead. A
                -- legible terminal beats a transparent one.
                config.window_background_opacity = ${if isDarwin then "1.0" else "0.70"}
                config.hide_tab_bar_if_only_one_tab = true
                config.default_cursor_style = 'BlinkingBlock'
                config.cursor_blink_rate = 200
                config.cursor_thickness = 1
                config.window_close_confirmation = 'NeverPrompt'

                -- Ctrl+= / Ctrl+- change how much fits in the window, not how
                -- big the window is. The default holds rows x columns fixed and
                -- resizes the window to match the new cell size, which moves and
                -- rescales the window every time the font changes.
                config.adjust_window_size_when_changing_font_size = false
                config.term = 'wezterm'
                ${optionalString isDarwin ''
                  -- TERM=wezterm is only usable if the shell can resolve that
                  -- terminfo entry AT STARTUP. On macOS wezterm is launched by
                  -- LaunchServices, whose environment has no TERMINFO_DIRS, so
                  -- zsh looks the terminal up before /etc/zshenv can set one,
                  -- fails, and DISABLES ZLE -- which breaks line editing: with no
                  -- cursor control, syntax highlighting redraws append instead of
                  -- overwrite and typed characters appear duplicated. ncurses
                  -- caches that first failure, so setting the variable later in
                  -- shell startup does not repair it.
                  --
                  -- Naming the terminfo package directly rather than a profile
                  -- keeps this correct for root and for any shell, not just an
                  -- interactive login one. Linux needs none of this: the system
                  -- profile aggregates terminfo and the lookup already succeeds.
                  -- weztermPackage, not pkgs.wezterm: `terminal.package` decides
                  -- which wezterm is INSTALLED, and terminfo that describes a
                  -- different build is the exact mismatch this block exists to
                  -- prevent. `.terminfo` is a passthru and survives override /
                  -- overrideAttrs; a package without one fails evaluation here,
                  -- which is louder and better than silently pointing at the
                  -- wrong build.
                  config.set_environment_variables = {
                    TERMINFO_DIRS = '${weztermPackage.terminfo}/share/terminfo:/usr/share/terminfo',
                  }
                ''}
                config.check_for_updates = false

                -- Vogix theme colors (live-reloaded on theme switch via SIGUSR1)
                local colors_file = (os.getenv("XDG_STATE_HOME") or os.getenv("HOME") .. "/.local/state") .. "/vogix/current-theme/wezterm/colors.lua"
                local ok, theme_colors = pcall(dofile, colors_file)
                if ok and theme_colors then config.colors = theme_colors end

                -- Selection behavior
                config.selection_word_boundary = ' \t\n{}"\'`,;:'
              '';
            }

            # wezterm.lua must end in `return config` or wezterm reports
            # "Cannot convert `Null` to `Config`" and falls back to defaults.
            #
            # When vogix manages this user it appends its keybindings AND that
            # return through its own `mkAfter`, so emitting one here too would put
            # a statement after a `return` -- a Lua syntax error. When vogix is not
            # in play (any darwin host, or a Linux host with theming.vogix off)
            # nothing closes the file, so this does.
            (mkIf (!(userCfg.theming.vogix.enable or false)) {
              extraConfig = mkAfter ''

                return config
              '';
            })
            # Merge settings if provided
            weztermSettings
          ];
        }
      )
      (activeUsers config.my.users);
  };
}
