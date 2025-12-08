{ config, lib, pkgs, ... }:

with lib;

{
  config = {
    home-manager.users = mapAttrs
      (name: userCfg:
        let
          launcher = userCfg.environment.launcher;
          hasWalker = launcher != null && launcher.enable && launcher.package.pname or "" == "walker";
        in
        mkIf hasWalker {
          home.packages = with pkgs; [
            walker
            libqalculate # For calculator functionality
            fd # For file finder functionality
            wshowkeys # For screencasting - show keypresses
          ];

          # Enable walker as a systemd service
          systemd.user.services.walker = {
            Unit = {
              Description = "Walker application launcher service";
              PartOf = [ "graphical-session.target" ];
            };
            Service = {
              ExecStart = "${pkgs.walker}/bin/walker --gapplication-service";
              Restart = "on-failure";
            };
            Install = {
              WantedBy = [ "graphical-session.target" ];
            };
          };

          # Walker configuration
          home.file.".config/walker/config.toml".text = ''
            # Walker configuration - simple and clean
            close_when_open = true
            theme = "large"
            hotreload_theme = true
            force_keyboard_focus = true
            timeout = 60
            ignore_elephant = true

            [list]
            max_entries = 200
            cycle = true

            [search]
            placeholder = " Search..."

            [builtins.applications]
            launch_prefix = ""
            placeholder = " Search..."
            prioritize_new = false
            context_aware = false
            show_sub_when_single = false
            history = true
            icon = ""

            [builtins.applications.actions]
            enabled = false
            hide_category = true

            [builtins.bookmarks]
            hidden = false

            [builtins.calc]
            name = "Calculator"
            icon = ""
            min_chars = 3
            prefix = "="

            [builtins.windows]
            switcher_only = false
            hidden = false

            [builtins.clipboard]
            hidden = false

            [builtins.commands]
            hidden = false

            [builtins.custom_commands]
            hidden = true

            [builtins.emojis]
            name = "Emojis"
            icon = ""
            prefix = ":"

            [builtins.symbols]
            after_copy = ""
            hidden = true

            [builtins.finder]
            use_fd = true
            min_chars = 1
            cmd = "sh -c 'xdg-open \"%RESULT%\"'"
            cmd_alt = "sh -c 'xdg-open \"$(dirname \"%RESULT%\")\";'"
            icon = "file"
            name = "Finder"
            preview_images = true
            hidden = false
            prefix = "."
            search_dirs = ["/home/${name}"]

            [builtins.runner]
            shell_config = ""
            switcher_only = false
            hidden = false
            prefix = ">"

            [builtins.ssh]
            hidden = false
            cmd = "$TERMINAL -e bash -c 'ssh %RESULT%; exec bash'"

            [builtins.websearch]
            switcher_only = false
            hidden = true

            [builtins.translation]
            hidden = true
          '';

          # Custom theme for larger window size
          home.file.".config/walker/themes/large.toml".text = ''
            # Custom Walker theme with larger window
            
            [ui]
            layer = "top"
            exclusive = false
            
            [ui.anchors]
            bottom = false
            left = false
            right = false
            top = false

            [ui.window]
            h_align = "center"
            v_align = "center"

            [ui.window.box]
            h_align = "center"
            width = 800  # Increased from 450

            [ui.window.box.margins]
            top = 0
            bottom = 0
            left = 0
            right = 0

            [ui.window.box.ai_scroll]
            name = "aiScroll"
            h_align = "fill"
            v_align = "fill"
            max_height = 500  # Increased from 300
            min_width = 750   # Increased from 400
            height = 500      # Increased from 300
            width = 750       # Increased from 400

            [ui.window.box.ai_scroll.margins]
            top = 8

            [ui.window.box.ai_scroll.list]
            name = "aiList"
            orientation = "vertical"
            width = 750  # Increased from 400
            spacing = 10

            [ui.window.box.ai_scroll.list.item]
            name = "aiItem"
            h_align = "fill"
            v_align = "fill"
            x_align = 0
            y_align = 0
            wrap = true

            [ui.window.box.scroll.list]
            marker_color = "#1BFFE1"
            max_height = 500  # Increased from 300
            max_width = 750   # Increased from 400
            min_width = 750   # Increased from 400
            width = 750       # Increased from 400

            [ui.window.box.scroll.list.item.activation_label]
            h_align = "fill"
            v_align = "fill"
            width = 20
            x_align = 0.5
            y_align = 0.5

            [ui.window.box.scroll.list.item.icon]
            pixel_size = 32  # Increased from 26
            theme = ""

            [ui.window.box.scroll.list.margins]
            top = 8

            [ui.window.box.search.prompt]
            name = "prompt"
            icon = "edit-find"
            theme = ""
            pixel_size = 20  # Increased from 18
            h_align = "center"
            v_align = "center"

            [ui.window.box.search.clear]
            name = "clear"
            icon = "edit-clear"
            theme = ""
            pixel_size = 20  # Increased from 18
            h_align = "center"
            v_align = "center"

            [ui.window.box.search.input]
            h_align = "fill"
            h_expand = true
            icons = true

            [ui.window.box.search.spinner]
            hide = true
          '';

          # Custom CSS for clean Hyprland-style window
          home.file.".config/walker/themes/large.css".text = ''
            /* Walker - clean floating window style */
            
            /* Main window - solid background like normal Hyprland windows */
            window {
              background-color: #2d2d2d;
              border-radius: 8px;
              border: 2px solid #565656;
              box-shadow: 0 4px 16px rgba(0, 0, 0, 0.3);
            }
            
            /* Search input styling */
            .search {
              background-color: #3d3d3d;
              border-radius: 6px;
              border: 1px solid #555555;
              padding: 10px 14px;
              margin: 12px;
              color: #ffffff;
              font-size: 14px;
            }
            
            /* Search input focus */
            .search:focus {
              border-color: #7c7c7c;
              outline: none;
            }
            
            /* List background */
            .list {
              background-color: #2d2d2d;
              padding: 8px;
              margin: 0 12px 12px 12px;
            }
            
            /* List items */
            .item {
              background-color: transparent;
              border-radius: 4px;
              padding: 10px 12px;
              margin: 1px 0;
              color: #ffffff;
              transition: background-color 0.15s ease;
            }
            
            /* Hovered/selected item */
            .item:selected,
            .item:hover {
              background-color: #4a4a4a;
              color: #ffffff;
            }
            
            /* Item text */
            .item label {
              color: #ffffff;
              font-size: 14px;
            }
            
            /* Icons */
            .item image {
              margin-right: 10px;
            }
            
            /* Scrollbar styling */
            scrollbar {
              background-color: #2d2d2d;
              border-radius: 4px;
              width: 8px;
            }
            
            scrollbar slider {
              background-color: #555555;
              border-radius: 4px;
              min-height: 20px;
            }
            
            scrollbar slider:hover {
              background-color: #666666;
            }
          '';
        }
      )
      config.my.users;
  };
}
