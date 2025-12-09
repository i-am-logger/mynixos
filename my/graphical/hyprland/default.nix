{ config, lib, pkgs, ... }:

with lib;

let
  # Auto-enable when any user has graphical.enable = true
  anyUserGraphical = any (userCfg: userCfg.graphical.enable or false) (attrValues config.my.users);

  # Swappy config
  swappyConfig = ''
    [Default]
    save_dir=$HOME/Pictures/screenshots
    save_filename_format=%Y-%m_%d-%H%M%S.png
    show_panel=true
    line_size=5
    text_size=20
    text_font=sans-serif
    paint_mode=arrow #brush|text|rectangle|ellipse|arrow|blur
    early_exit=false
    fill_shape=false
  '';

  # Hyprland configuration modules
  animations = {
    enabled = true;
    bezier = "myBezier, 0.05, 0.9, 0.1, 1.05";
    animation = [
      "windows, 1, 2, myBezier"
      "windowsIn, 1, 2, myBezier, slide"
      "windowsOut, 1, 2, myBezier, slide"
      "windowsMove, 1, 2, myBezier"
      # "windowsOut, 1, 2, default, popin 80%"
      "border, 1, 2, default"
      "borderangle, 1, 2, default"
      "fade, 1, 2, default"
      "workspaces, 1, 2, default"
    ];
  };

  autostart = [
    "dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP &"
    "systemctl --user import-environment WAYLAND_DISPLAY XDG_CURRENT_DESKTOP"
    # "gsettings set org.gnome.desktop.interface cursor-theme 'Bibata-Modern-Amber'"
    # "gsettings set org.gnome.desktop.interface cursor-size 24"
    "1password --silent &"
    "wl-paste --watch cliphist store"
    # "waybar &"  # Backup option if systemd service doesn't work
  ];

  # mynixos opinionated defaults for Hyprland input settings
  # Note: browser/terminal come from environment API (userCfg.environment.BROWSER/TERMINAL)
  defaults = {
    leftHanded = false;
    sensitivity = 0.0;
  };

  # Bindings function - takes user hyprland config and environment-derived commands
  mkBindings = { userHyprland, browserCmd, terminalCmd }: {
    # MAINMOD
    "$mainMod" = "SUPER";

    # quickly launch program
    bind = [
      "$mainMod, Space, exec, walker -p 'Start…' -w 1000 -h 700"
      "$mainMod SHIFT, Space, exec, walker --modules ssh -w 1000 -h 700"
      "$mainMod, E, exec, ${browserCmd}"
      "$mainMod SHIFT, E, exec, google-chrome-stable"
      "SHIFT, Print, exec, grimblast save area - | swappy -f -"
      ", Print, exec, grimblast --notify copy area"

      # COLORPICKER
      "$mainMod SHIFT, P, exec, hyprpicker -a"

      # SHOW KEYS (for screencasting)
      "$mainMod SHIFT, S, exec, pkill wshowkeys || wshowkeys -a bottom -F 'Source Code Pro 24' -t 2 -m 50"

      "$mainMod SHIFT, X, exec, hyprlock"

      # Walker additional modes (Omarchy style)
      "$mainMod, period, exec, walker -p 'Find files… (type . then filename)' -w 1000 -h 700 -q '.'"
      "$mainMod, equal, exec, walker -p 'Calculator… (type = then expression)' -w 1000 -h 700 -q '='"
      "$mainMod, semicolon, exec, walker -p 'Emojis… (type : then emoji name)' -w 1000 -h 700 -q ':'"

      # general bindings
      "$mainMod, T, exec, ${terminalCmd}"
      "$mainMod, Q, killactive,"
      "$mainMod, Y, togglefloating,"
      "$mainMod, F, fullscreen"
      "$mainMod, I, pin"
      "$mainMod, P, pseudo," # dwindle
      "$mainMod, O, togglesplit," # dwindle

      # Toggle grouped layout
      "$mainMod, U, togglegroup,"
      "$mainMod, bracketleft, changegroupactive, f"
      "$mainMod, bracketright, changegroupactive, b"

      # change gap
      "$mainMod SHIFT, G, exec, hyprctl --batch \"keyword general:gaps_out 5;keyword general:gaps_in 6\""
      "$mainMod, G, exec, hyprctl --batch \"keyword general:gaps_out 0;keyword general:gaps_in 0\""

      # Move focus with mainMod + arrow keys
      "$mainMod, left, movefocus, l"
      "$mainMod, right, movefocus, r"
      "$mainMod, up, movefocus, u"
      "$mainMod, down, movefocus, d"
      "$mainMod, h, movefocus, l"
      "$mainMod, l, movefocus, r"
      "$mainMod, k, movefocus, u"
      "$mainMod, j, movefocus, d"

      # move window in current workspace
      "$mainMod SHIFT, left, swapwindow, l"
      "$mainMod SHIFT, right, swapwindow, r"
      "$mainMod SHIFT, up, swapwindow, u"
      "$mainMod SHIFT, down, swapwindow, d"
      "$mainMod SHIFT, h, swapwindow, l"
      "$mainMod SHIFT, l, swapwindow, r"
      "$mainMod SHIFT, k, swapwindow, u"
      "$mainMod SHIFT, j, swapwindow, d"

      # resize window
      "ALT, R, submap, resize"

      # Switch workspaces with mainMod + [0-9]
      "$mainMod, 1, workspace, 1"
      "$mainMod, 2, workspace, 2"
      "$mainMod, 3, workspace, 3"
      "$mainMod, 4, workspace, 4"
      "$mainMod, 5, workspace, 5"
      "$mainMod, 6, workspace, 6"
      "$mainMod, 7, workspace, 7"
      "$mainMod, 8, workspace, 8"
      "$mainMod, 9, workspace, 9"
      "$mainMod, 0, workspace, 10"
      "$mainMod, C, workspace, Chat"
      "$mainMod, M, workspace, Music"

      "$mainMod CTRL, left, workspace, -1"
      "$mainMod CTRL, right, workspace, +1"
      "$mainMod CTRL, h, workspace, -1"
      "$mainMod CTRL, l, workspace, +1"

      # Move active window to a workspace with mainMod + ctrl + [0-9]
      "$mainMod CTRL, 1, movetoworkspace, 1"
      "$mainMod CTRL, 2, movetoworkspace, 2"
      "$mainMod CTRL, 3, movetoworkspace, 3"
      "$mainMod CTRL, 4, movetoworkspace, 4"
      "$mainMod CTRL, 5, movetoworkspace, 5"
      "$mainMod CTRL, 6, movetoworkspace, 6"
      "$mainMod CTRL, 7, movetoworkspace, 7"
      "$mainMod CTRL, 8, movetoworkspace, 8"
      "$mainMod CTRL, 9, movetoworkspace, 9"
      "$mainMod CTRL, 0, movetoworkspace, 10"
      "$mainMod CTRL SHIFT, left, movetoworkspace, -1"
      "$mainMod CTRL SHIFT, right, movetoworkspace, +1"
      "$mainMod CTRL SHIFT, h, movetoworkspace, -1"
      "$mainMod CTRL SHIFT, l, movetoworkspace, +1"

      # same as above, but doesnt switch to the workspace
      "$mainMod SHIFT, 1, movetoworkspacesilent, 1"
      "$mainMod SHIFT, 2, movetoworkspacesilent, 2"
      "$mainMod SHIFT, 3, movetoworkspacesilent, 3"
      "$mainMod SHIFT, 4, movetoworkspacesilent, 4"
      "$mainMod SHIFT, 5, movetoworkspacesilent, 5"
      "$mainMod SHIFT, 6, movetoworkspacesilent, 6"
      "$mainMod SHIFT, 7, movetoworkspacesilent, 7"
      "$mainMod SHIFT, 8, movetoworkspacesilent, 8"
      "$mainMod SHIFT, 9, movetoworkspacesilent, 9"
      "$mainMod SHIFT, 0, movetoworkspacesilent, 10"

      # Scroll through existing workspaces with mainMod + scroll
      "$mainMod, mouse_down, workspace, e+1"
      "$mainMod, mouse_up, workspace, e-1"

      # control volume,brightness,media players
      ", XF86AudioRaiseVolume, exec, pamixer -i 5"
      ", XF86AudioLowerVolume, exec, pamixer -d 5"
      ", XF86AudioMute, exec, pamixer -t"
      ", XF86AudioMicMute, exec, pamixer --default-source -t"
      # Custom mic toggle with notification (for Stream Deck compatibility)
      "$mainMod SHIFT, M, exec, ~/.local/bin/mic-toggle"
      ", XF86MonBrightnessUp, exec, light -A 5"
      ", XF86MonBrightnessDown, exec, light -U 5"
      ", XF86AudioPlay, exec, playerctl play-pause"
      ", XF86AudioNext, exec, playerctl next"
      ", XF86AudioPrev, exec, playerctl previous"

      # Notification controls
      "$mainMod, N, exec, makoctl dismiss"
      "$mainMod SHIFT, N, exec, makoctl dismiss --all"
      "$mainMod CTRL, N, exec, ~/.local/bin/toggle-dnd"
    ];

    binde = [
      "CTRL SHIFT, left, resizeactive, -30 0"
      "CTRL SHIFT, right, resizeactive, 30 0"
      "CTRL SHIFT, up, resizeactive, 0 -30"
      "CTRL SHIFT, down, resizeactive, 0 30"
      "CTRL SHIFT, h, resizeactive, -30 0"
      "CTRL SHIFT, l, resizeactive, 30 0"
      "CTRL SHIFT, k, resizeactive, 0 -30"
      "CTRL SHIFT, j, resizeactive, 0 30"
    ];

    bindm = [
      "$mainMod, mouse:272, movewindow"
      "$mainMod, mouse:273, resizewindow"
    ];

    # switch between current and last workspace
    binds = {
      workspace_back_and_forth = false;
      allow_workspace_cycles = false;
    };
  };

  # Decoration settings for Hyprland 0.51+
  # blur must be nested under decoration, not at top level
  decorations = {
    active_opacity = 1.0;
    inactive_opacity = 1.0;
    fullscreen_opacity = 1.0;
    rounding = 8;
    dim_inactive = true;
    dim_strength = 0.3; # 0.0 ~ 1.0
    # Note: blur is defined here but home-manager may flatten it
    # See decorationBlur below for workaround
  };

  # Separate blur config for explicit nesting
  decorationBlur = {
    enabled = true;
    brightness = 0.7;
    size = 3;
  };

  environment = {
    monitor = [
      ",highres,auto,1"
      # ",highrr,auto,1"
      # ", preferred, auto, 1"
      # "eDP-1,disable"
    ];

    env = [
      # "XCURSOR_SIZE,24"
      # "XCURSOR_THEME,Bibata-Modern-Amber"
      # "GDK_SCALE,2"
      # "XDG_SESSION_TYPE,wayland"
      # "WLR_NO_HARDWARE_CURSORS,1"
      # "HYPRLAND_SOCKET_PATH,/tmp/hypr"
    ];
  };

  general = {
    gaps_in = 10;
    gaps_out = 10;
    border_size = 3;
    layout = "dwindle";
  };

  group = {
    groupbar = {
      font_family = "Fira Code Nerd Font";
      font_size = 28;
      height = 32;
      indicator_height = 5;
    };
  };

  # Layer rules for better performance
  layerrule = [
    "noanim, walker" # Disable animations for Walker launcher
    "blur, walker"
  ];

  gestures = {
    #workspace_swipe = true
    #workspace_swipe_fingers = 4
    #workspace_swipe_distance = 250
    #workspace_swipe_invert = true
    #workspace_swipe_min_speed_to_force = 15
  };

  # Input function (takes user config as parameter)
  mkInput = userHyprland: {
    #kb_layout = us
    #kb_variant = us,il
    #kb_model =
    #kb_options = caps:escape
    #kb_rules =
    #repeat_rate = 30
    repeat_delay = 200;
    left_handed = userHyprland.leftHanded or defaults.leftHanded;
    #follow_mouse = 2 # 0|1|2|3
    float_switch_override_focus = 2;
    numlock_by_default = "off";
    natural_scroll = "yes";

    touchpad = {
      natural_scroll = 1;
      disable_while_typing = true;
      #clickfinger_behavior = true
      #middle_button_emulation = true
      scroll_factor = 0.3;
    };

    sensitivity = userHyprland.sensitivity or defaults.sensitivity;
  };

  layouts = {
    dwindle = {
      force_split = 2;
      preserve_split = true;
      smart_resizing = true;
      use_active_for_splits = true;
    };

    master = {
      orientation = "center";
      special_scale_factor = 0.5;
    };
  };

  misc = {
    disable_autoreload = false;
    disable_hyprland_logo = true;
    always_follow_on_dnd = true;
    layers_hog_keyboard_focus = true;
    animate_manual_resizes = true;
    enable_swallow = false;
    # swallow_regex =
    focus_on_activate = true;
    font_family = "Fira Code Nerd Font";
    # background_color = "121212";
  };

  windowRules = {
    windowrule = [ ]; # Empty since we're converting all rules to windowrulev2

    windowrulev2 = [
      # Walker - Application launcher overlay
      "float,class:^(walker)$"
      "stayfocused,class:^(walker)$"
      "pin,class:^(walker)$"
      "noborder,class:^(walker)$"
      "noblur,class:^(walker)$"

      # 1Password: 20% margins from edges
      "float,class:^(1Password)$"
      "center,class:^(1Password)$"
      "size 60% 70%,class:^(1Password)$"
      "workspace 20% 20%,class:^(1Password)$"

      # PulseAudio Volume Control
      "float,class:^(org.pulseaudio.pavucontrol)$"
      "center,class:^(org.pulseaudio.pavucontrol)$"
      "size 50% 60%,class:^(org.pulseaudio.pavucontrol)$"
      "workspace 25% 20%,class:^(org.pulseaudio.pavucontrol)$"

      # Bluetooth Manager
      "float,class:^(.blueman-manager-wrapped)$"
      "center,class:^(.blueman-manager-wrapped)$"
      "size 40% 50%,class:^(.blueman-manager-wrapped)$"
      "workspace 30% 25%,class:^(.blueman-manager-wrapped)$"

      # Network Manager
      "float,class:^(nm-connection-editor)$"
      "center,class:^(nm-connection-editor)$"
      "size 40% 50%,class:^(nm-connection-editor)$"
      "workspace 30% 25%,class:^(nm-connection-editor)$"

      # GTK Portal
      "float,class:^(xdg-desktop-portal-gtk)$"
      "center,class:^(xdg-desktop-portal-gtk)$"
      "size 40% 50%,class:^(xdg-desktop-portal-gtk)$"
      "workspace 30% 25%,class:^(xdg-desktop-portal-gtk)$"

      # Brave Save Dialog
      "float,class:^(brave)$,title:^(Save File)$"
      "center,class:^(brave)$,title:^(Save File)$"
      "size 50% 60%,class:^(brave)$,title:^(Save File)$"
      "workspace 25% 20%,class:^(brave)$,title:^(Save File)$"

      # Slack - Main window rules
      "tile,class:^(Slack)$,title:^(.*)$"
      "suppressevent maximize,class:^(Slack)$"

      # Slack - Hide/suppress menu windows and popups
      "nofocus,class:^(Slack)$,title:^$"
      "noinitialfocus,class:^(Slack)$,title:^$"
      "float,class:^(Slack)$,title:^$"
      "size 0 0,class:^(Slack)$,title:^$"
      "move -1000 -1000,class:^(Slack)$,title:^$"

      # Slack - Handle context menus and dropdowns
      "float,class:^(Slack)$,title:^(Context Menu)$"
      "nofocus,class:^(Slack)$,title:^(Context Menu)$"
      "size 0 0,class:^(Slack)$,title:^(Context Menu)$"
    ];
  };
in
{
  # Option is declared in flake.nix
  config = mkIf anyUserGraphical {
    home-manager.users = mapAttrs
      (name: userCfg:
        let
          # Get user-level hyprland config (with mynixos opinionated defaults)
          userHyprland = userCfg.apps.graphical.windowManagers.hyprland or { };

          # Get browser/terminal from environment API (single source of truth)
          browserApp = userCfg.environment.BROWSER or null;
          terminalApp = userCfg.environment.TERMINAL or null;

          # Derive command paths from packages
          # Falls back to opinionated defaults if environment not set
          browserCmd =
            if browserApp != null && (browserApp.enable or false)
            then browserApp.package.meta.mainProgram or browserApp.package.pname or "brave"
            else "brave";

          terminalCmd =
            if terminalApp != null && (terminalApp.enable or false)
            then terminalApp.package.meta.mainProgram or terminalApp.package.pname or "wezterm"
            else "wezterm";
        in
        mkIf (userCfg.graphical.enable && userHyprland.enable) {
        # GTK configuration
        # Stylix automatically sets gtk.theme.name and gtk.iconTheme.name
        gtk = {
          enable = true;
        };

        # Notification daemon with Stylix theming
        services.mako = {
          enable = true;
          # Stylix handles colors automatically, we just set behavior
          settings = {
            # Behavior
            default-timeout = 5000; # 5 seconds
            ignore-timeout = true; # Don't auto-dismiss critical notifications (like GPG/YubiKey)
            layer = "overlay";

            # Position and sizing - adjusted for better readability
            anchor = "top-center";
            width = 800; # Much wider for big text
            height = 200; # A bit taller too
            margin = "60,20,10,20"; # top,right,bottom,left - lower and more centered
            padding = "20";
            border-size = 2;
            border-radius = 8;

            # Behavior
            max-visible = 5;
            sort = "+time"; # Newest on top

            # Note: Mako doesn't support animations
            # For smooth animations, consider using swaync or dunst instead
          };

          # GPG/YubiKey specific - don't timeout critical notifications
          extraConfig = ''
            [urgency=critical]
            ignore-timeout=1
            default-timeout=0

            [app-name="yubikey-touch-detector"]
            ignore-timeout=1
            default-timeout=15000
            border-color=#f38ba8

            # Do-not-disturb mode - still show critical notifications (like YubiKey)
            [mode=do-not-disturb]
            invisible=1

            [mode=do-not-disturb urgency=critical]
            invisible=0

            [mode=do-not-disturb app-name="yubikey-touch-detector"]
            invisible=0
          '';

          # Note: Key bindings are handled via Hyprland keybindings and makoctl
          # Super+N = dismiss newest notification
          # Super+Shift+N = dismiss all notifications
          # Super+Ctrl+N = toggle do-not-disturb mode
        };

        # DND toggle script
        home.file.".local/bin/toggle-dnd" = {
          text = ''
            #!/usr/bin/env bash

            # Toggle mako do-not-disturb mode and show notification feedback

            # Get current mode
            current_mode=$(makoctl mode)

            # Toggle the mode
            makoctl mode -t do-not-disturb

            # Get new mode
            new_mode=$(makoctl mode)

            # Show appropriate notification
            if [[ "$new_mode" == "do-not-disturb" ]]; then
                # Temporarily disable DND to show the notification, then re-enable it after delay
                makoctl mode -r do-not-disturb
                notify-send "🔕 Do Not Disturb" "Notifications are now hidden (except critical)" --urgency=normal --expire-time=2500 &
                sleep 2.8  # Wait long enough for notification to be visible
                makoctl mode -s do-not-disturb
            else
                notify-send "🔔 Notifications Enabled" "All notifications are now visible" --urgency=normal --expire-time=3000
            fi
          '';
          executable = true;
        };

        # Swappy config for screenshots
        xdg.configFile."swappy/config".text = swappyConfig;

        # Home packages
        home.packages = with pkgs; [
          # XDG portals are provided by programs.hyprland.enable in graphical.nix
          # Don't add xdg-desktop-portal-hyprland here to avoid conflicts
          brightnessctl
          swww
          waypaper
          swaybg
          grimblast
          slurp
          swappy
          wl-clipboard
          cliphist
          udiskie
          vlc
          hyprpicker
          wlogout
          networkmanagerapplet
          pavucontrol
          pamixer
          playerctl
          gtk3
        ];

        # Hyprland configuration
        wayland.windowManager.hyprland = {
          enable = true;
          xwayland = {
            enable = true;
          };
          settings = {
            # General settings - nested under general block
            general = {
              inherit (general) gaps_in gaps_out border_size layout;
            };

            # Input settings
            input = mkInput userHyprland;

            # Layouts
            inherit (layouts) dwindle master;

            # Misc
            inherit misc;

            # Groups
            inherit group;

            # Gestures
            inherit gestures;

            # Animations
            inherit animations;

            # Decoration - properly structured for Hyprland 0.51+
            # This merges with stylix's decoration settings
            decoration = {
              inherit (decorations) active_opacity inactive_opacity fullscreen_opacity rounding dim_inactive dim_strength;

              blur = {
                inherit (decorationBlur) enabled brightness size;
              };

              # Shadow color managed by stylix theming
            };

            # Window and layer rules
            inherit layerrule;
            inherit (windowRules) windowrule windowrulev2;

            # Environment
            inherit (environment) monitor env;

            # Autostart
            exec-once = autostart;
          } // (mkBindings { inherit userHyprland browserCmd terminalCmd; });
        };
      }) # End mkIf userHyprland.enable
      config.my.users;
  };
}
