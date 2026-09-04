{ activeUsers
, config
, lib
, pkgs
, vogix
, ...
}:

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

  # Hyprland configuration modules. The legacy bezier/animation strings are
  # the single source; the Lua renderer parses the same strings into
  # hl.curve/hl.animation shapes (vogix's hypr-lua projection helpers).
  animationBezier = "myBezier, 0.05, 0.9, 0.1, 1.05";
  animationRules = [
    "windows, 1, 2, myBezier"
    "windowsIn, 1, 2, myBezier, slide"
    "windowsOut, 1, 2, myBezier, slide"
    "windowsMove, 1, 2, myBezier"
    "border, 1, 2, default"
    "borderangle, 1, 2, default"
    "fade, 1, 2, default"
    "workspaces, 1, 2, default"
    "specialWorkspace, 1, 3, myBezier, slidefadevert top"
  ];

  mkAnimations = userHyprland: {
    enabled = userHyprland.animations_enabled;
    bezier = animationBezier;
    animation = animationRules;
  };

  # Secrets never reach clipboard history: password managers mark their
  # copies with x-kde-passwordManagerHint, and this store step drops those
  # offers entirely — a 1Password copy must not sit in cliphist verbatim.
  cliphistStoreGuarded = pkgs.writeShellScript "cliphist-store-guarded" ''
    if ${pkgs.wl-clipboard}/bin/wl-paste --list-types | ${pkgs.gnugrep}/bin/grep -qx 'x-kde-passwordManagerHint'; then
      exit 0
    fi
    exec ${pkgs.cliphist}/bin/cliphist store
  '';

  # `hyprctl instances -j` is the only source of the compositor's identity that
  # a systemd unit can actually read: it scans $XDG_RUNTIME_DIR/hypr and needs
  # no session environment of its own, and /proc/<hyprland>/environ is closed
  # to us because kernel.yama.ptrace_scope is 1.
  #
  # Two sharp edges are handled here rather than at each call site. With no
  # instance running, `hyprctl instances -j` exits 0 having printed "\n]\n\n" —
  # not valid JSON and not the empty array — so nothing may test its text; the
  # only trustworthy signal is whether jq yielded any line at all. And a
  # crashed compositor can leave a stale directory behind, so a signature
  # counts as live only once its IPC socket has answered, which is what the
  # round-trip through `hyprctl version` establishes.
  #
  # Emits `candidates`, newest first, one "<signature> <wl socket>" per line,
  # and a `live` predicate. Exits 0 when there is no compositor to talk to:
  # both callers treat that as "nothing to do", never as a failure.
  liveInstances = ''
    candidates=$(
      ${config.programs.hyprland.package}/bin/hyprctl instances -j 2>/dev/null \
        | ${pkgs.jq}/bin/jq -r 'sort_by(.time) | reverse | .[] | "\(.instance) \(.wl_socket)"' 2>/dev/null
    ) || true
    if [ -z "$candidates" ]; then
      exit 0
    fi
    live() {
      HYPRLAND_INSTANCE_SIGNATURE="$1" \
        ${config.programs.hyprland.package}/bin/hyprctl version >/dev/null 2>&1
    }
  '';

  # Hyprland exports WAYLAND_DISPLAY and HYPRLAND_INSTANCE_SIGNATURE into the
  # user manager exactly once, from its `hyprland.start` hook. If the user
  # manager is ever replaced while the compositor keeps running — user@<uid>
  # exiting and a later login re-creating it, which is what happened on yoga —
  # the new manager has neither, and every Wayland client started as a user
  # unit dies. quickshell dies hardest: with no WAYLAND_DISPLAY the wayland
  # plugin cannot open a display and (with no DISPLAY) xcb cannot either, so
  # Qt's init_platform calls qFatal and the process aborts inside its own
  # crash handler. Re-importing from the live compositor on every raise of the
  # session makes the environment a property of the session rather than of the
  # compositor's first second.
  hyprlandSessionEnv = pkgs.writeShellScript "hyprland-session-env" ''
    set -uo pipefail
    ${liveInstances}
    while read -r sig sock; do
      [ -n "$sig" ] || continue
      if live "$sig"; then
        echo "importing WAYLAND_DISPLAY=$sock from Hyprland instance $sig" >&2
        exec ${pkgs.dbus}/bin/dbus-update-activation-environment --systemd \
          "WAYLAND_DISPLAY=$sock" \
          "HYPRLAND_INSTANCE_SIGNATURE=$sig" \
          "XDG_CURRENT_DESKTOP=Hyprland" \
          "XDG_SESSION_TYPE=wayland"
      fi
    done <<EOF
    $candidates
    EOF
    echo "Hyprland instances exist but none answered on its IPC socket" >&2
    exit 1
  '';

  # The same one-shot hook is also the only thing that ever starts
  # hyprland-session.target, so a replaced user manager leaves the compositor
  # running with no session behind it — on yoga that was a four-hour outage
  # that ended only because the target was raised by hand. A fresh manager
  # asks the question the compositor can no longer answer: is there a live
  # Hyprland with no session? At a normal login there is not (greetd starts
  # Hyprland after the manager), so this is a no-op on the ordinary path.
  hyprlandSessionRecover = pkgs.writeShellScript "hyprland-session-recover" ''
    set -uo pipefail
    if ${config.systemd.package}/bin/systemctl --user --quiet is-active hyprland-session.target; then
      exit 0
    fi
    ${liveInstances}
    while read -r sig _; do
      [ -n "$sig" ] || continue
      if live "$sig"; then
        echo "Hyprland $sig is live but hyprland-session.target is not; raising it" >&2
        # --no-block: this runs inside the default.target transaction, and the
        # session target must not be enqueued as something that transaction waits on.
        exec ${config.systemd.package}/bin/systemctl --user --no-block start hyprland-session.target
      fi
    done <<EOF
    $candidates
    EOF
    exit 0
  '';

  autostart = [
    # NOTE: the Wayland/Hyprland session environment import lives in home-manager's
    # Hyprland systemd integration (it emits the complete
    # `dbus-update-activation-environment --systemd DISPLAY HYPRLAND_INSTANCE_SIGNATURE
    # WAYLAND_DISPLAY XDG_CURRENT_DESKTOP && systemctl --user restart
    # hyprland-session.target` as the first exec-once, ordered before
    # graphical-session.target members start). A second partial import here
    # (only WAYLAND_DISPLAY + XDG_CURRENT_DESKTOP, backgrounded/unordered) used
    # to live in this list — it imported neither HYPRLAND_INSTANCE_SIGNATURE nor
    # DISPLAY, raced the real import, and muddied diagnosis. Removed: the HM
    # integration is the canonical importer *at compositor start*. It is not the
    # only one: it fires once per Hyprland process, so a user manager that
    # restarts under a live compositor inherits neither the environment nor the
    # session target. hyprland-session-env.service below re-imports the
    # environment on every raise of the session, and
    # hyprland-session-recover.service raises the session when nothing else will.
    "1password --silent &"
    "wl-paste --watch ${cliphistStoreGuarded}"
  ];

  # Vogix behavior module (pure functions, no module system needed)
  behaviorModule = import "${vogix}/nix/modules/behavior" { inherit lib; };

  # Vogix's legacy→Lua projection helpers (dispatcher table, bind-line and
  # bezier/animation parsers) — the same table the vogix runtime uses, so the
  # two renderings cannot drift apart.
  luaLib = import "${vogix}/nix/modules/lib/hypr-lua.nix" { inherit lib; };
  inherit (lib.generators) mkLuaInline;

  # One catalog of fallback binds (used when vogix theming is off), rendered
  # to hyprlang strings or Lua bind elements depending on the config engine.
  # The two gap binds are the only engine-specific entries: raw `hyprctl
  # keyword` does not exist on the Lua engine, so that path speaks `eval`.
  mkBindLists =
    { browserCmd
    , terminalCmd
    , isLua
    }:
    let
      gapsOn =
        if isLua
        then "exec, hyprctl eval 'hl.config({ [\"general.gaps_out\"] = 5, [\"general.gaps_in\"] = 6 })'"
        else "exec, hyprctl --batch \"keyword general:gaps_out 5;keyword general:gaps_in 6\"";
      gapsOff =
        if isLua
        then "exec, hyprctl eval 'hl.config({ [\"general.gaps_out\"] = 0, [\"general.gaps_in\"] = 0 })'"
        else "exec, hyprctl --batch \"keyword general:gaps_out 0;keyword general:gaps_in 0\"";
    in
    {
      # quickly launch program. $LAUNCHER is the environment selector —
      # walker is gone from the fleet (its walker-flag mode binds went with
      # it; a selected launcher brings its own modes).
      bind = [
        "$mainMod, Space, exec, $LAUNCHER"
        "$mainMod, E, exec, ${browserCmd}"
        "$mainMod SHIFT, E, exec, chromium"
        "SHIFT, Print, exec, grimblast save area - | swappy -f -"
        ", Print, exec, grimblast --notify copy area"

        # COLORPICKER
        "$mainMod SHIFT, P, exec, hyprpicker -a"

        # SHOW KEYS (for screencasting)
        "$mainMod SHIFT, S, exec, pkill wshowkeys || wshowkeys -a bottom -F 'Source Code Pro 24' -t 2 -m 50"


        # general bindings
        "$mainMod, T, exec, ${terminalCmd}"
        "$mainMod, Q, killactive,"
        "$mainMod, Y, togglefloating,"
        "$mainMod, F, fullscreen"
        "$mainMod, I, pin"
        "$mainMod, p, pseudo," # dwindle
        "$mainMod, o, layoutmsg, togglesplit" # dwindle

        # Toggle grouped layout
        "$mainMod, U, togglegroup,"
        "$mainMod, bracketleft, changegroupactive, f"
        "$mainMod, bracketright, changegroupactive, b"

        # change gap
        "$mainMod SHIFT, G, ${gapsOn}"
        "$mainMod, G, ${gapsOff}"

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
    };

  # Hyprlang rendering of the fallback binds.
  mkBindings = args:
    let lists = mkBindLists (args // { isLua = false; });
    in
    {
      # MAINMOD
      "$mainMod" = "SUPER";

      inherit (lists) bind binde;

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

  # Lua rendering of the same fallback binds: every legacy line goes through
  # vogix's dispatcher translation; `binde` becomes the `repeating` opt; the
  # mouse binds become the drag/resize dispatchers (the legacy `bindm` flag
  # has no Lua form). `binds` moves into `hl.config` at the call site.
  mkLuaBinds = args:
    let lists = mkBindLists (args // { isLua = true; });
    in
    map (luaLib.legacyBindToLua { }) lists.bind
    ++ map (luaLib.legacyBindToLua { repeating = true; }) lists.binde
    ++ [
      { _args = [ "SUPER + mouse:272" (mkLuaInline "hl.dsp.window.drag()") ]; }
      { _args = [ "SUPER + mouse:273" (mkLuaInline "hl.dsp.window.resize()") ]; }
    ];

  # Decoration settings for Hyprland 0.51+
  # blur must be nested under decoration, not at top level
  mkDecorations = userHyprland: {
    inherit (userHyprland)
      active_opacity
      inactive_opacity
      rounding
      dim_inactive
      dim_strength
      ;
    fullscreen_opacity = 1.0;
  };

  # Separate blur config for explicit nesting
  mkDecorationBlur = userHyprland: {
    enabled = userHyprland.blur_enabled;
    brightness = 0.7;
    size = userHyprland.blur_size;
  };

  environment = {
    monitor = [
      ",highres,auto,1"
    ];
    env = [ ];
  };

  mkGeneral = userHyprland: {
    inherit (userHyprland)
      gaps_in
      gaps_out
      border_size
      layout
      ;
  };

  group = {
    groupbar = {
      font_family = "Fira Code Nerd Font";
      font_size = 28;
      height = 32;
      indicator_height = 5;
    };
  };

  gestures = { };

  # Input function (takes user config as parameter)
  # Pointer preferences come from my.users.<n>.input, not from the window
  # manager's own options: they belong to the person, and macOS consumes the same
  # ones via my/users/input/darwin.nix. Everything else in this block is
  # genuinely Hyprland behaviour with no counterpart elsewhere.
  mkInput = userInput: {
    #kb_model =
    #kb_options = caps:escape
    #kb_rules =
    #repeat_rate = 30
    repeat_delay = 200;
    left_handed = userInput.leftHanded;
    #follow_mouse = 2 # 0|1|2|3
    float_switch_override_focus = 2;
    numlock_by_default = "off";
    natural_scroll = if userInput.naturalScroll then "yes" else "no";

    touchpad = {
      natural_scroll = if userInput.naturalScroll then 1 else 0;
      disable_while_typing = true;
      #clickfinger_behavior = true
      #middle_button_emulation = true
      scroll_factor = 0.3;
    };

    sensitivity = userInput.accelSpeed;
  };

  # The same input block for the Lua engine: real booleans — the Lua bool
  # parser hard-rejects hyprlang's "yes"/"no"/"on"/"off" strings.
  mkInputLua = userInput:
    mkInput userInput // {
      numlock_by_default = false;
      natural_scroll = userInput.naturalScroll;
      touchpad = {
        natural_scroll = userInput.naturalScroll;
        disable_while_typing = true;
        scroll_factor = 0.3;
      };
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

  # Window rules using the new Hyprland 0.45+ syntax
  # Format: "match:<prop> <value>, <effect> <value>, ..."
  # Match props: class, title, initial_class, initial_title, float, tag, xwayland, fullscreen, pin, focus, group, modal, workspace
  # Effects: float, tile, fullscreen, maximize, move, size, center, pin, no_focus, no_blur, no_shadow, opacity, stay_focused, etc.
  windowRules = [
    # 1Password: centered floating window
    "match:class ^(1Password)$, float true, center true, size 60% 70%"

    # PulseAudio Volume Control
    "match:class ^(org.pulseaudio.pavucontrol)$, float true, center true, size 50% 60%"

    # Bluetooth Manager
    "match:class ^(.blueman-manager-wrapped)$, float true, center true, size 40% 50%"

    # Network Manager
    "match:class ^(nm-connection-editor)$, float true, center true, size 40% 50%"

    # GTK Portal
    "match:class ^(xdg-desktop-portal-gtk)$, float true, center true, size 40% 50%"

    # Brave Save Dialog
    "match:class ^(brave)$, match:title ^(Save File)$, float true, center true, size 50% 60%"

    # Slack - Main window rules (tile and suppress maximize)
    "match:class ^(Slack)$, match:title ^(.*)$, tile true"
    "match:class ^(Slack)$, suppress_event maximize"

    # Slack - Hide/suppress menu windows and popups (empty title)
    "match:class ^(Slack)$, match:title ^$, no_focus true, no_initial_focus true, float true, size 0 0, move -1000 -1000"

    # System console — window rules managed by vogix behavior module

    # Slack - Handle context menus and dropdowns
    "match:class ^(Slack)$, match:title ^(Context Menu)$, float true, no_focus true, size 0 0"
  ];

  # The same rules as hl.window_rule tables (the Lua engine). Every rule is
  # named: named rules deduplicate across reloads and get a handle. Field
  # names verified against the 0.56.2 effect table (float/tile/center/pin/
  # no_focus/no_initial_focus/no_blur/stay_focused are bools; size/move take
  # the legacy string form; suppress_event is a string).
  windowRulesLua = [
    # 1Password: centered floating window
    {
      name = "1password-center";
      match.class = "^(1Password)$";
      float = true;
      center = true;
      size = "60% 70%";
    }

    # PulseAudio Volume Control
    {
      name = "pavucontrol-center";
      match.class = "^(org.pulseaudio.pavucontrol)$";
      float = true;
      center = true;
      size = "50% 60%";
    }

    # Bluetooth Manager
    {
      name = "blueman-center";
      match.class = "^(.blueman-manager-wrapped)$";
      float = true;
      center = true;
      size = "40% 50%";
    }

    # Network Manager
    {
      name = "nm-editor-center";
      match.class = "^(nm-connection-editor)$";
      float = true;
      center = true;
      size = "40% 50%";
    }

    # GTK Portal
    {
      name = "gtk-portal-center";
      match.class = "^(xdg-desktop-portal-gtk)$";
      float = true;
      center = true;
      size = "40% 50%";
    }

    # Brave Save Dialog
    {
      name = "brave-save-dialog";
      match = { class = "^(brave)$"; title = "^(Save File)$"; };
      float = true;
      center = true;
      size = "50% 60%";
    }

    # Slack - Main window rules (tile and suppress maximize)
    {
      name = "slack-tile";
      match = { class = "^(Slack)$"; title = "^(.*)$"; };
      tile = true;
    }
    {
      name = "slack-suppress-maximize";
      match.class = "^(Slack)$";
      suppress_event = "maximize";
    }

    # Slack - Hide/suppress menu windows and popups (empty title)
    {
      name = "slack-menus";
      match = { class = "^(Slack)$"; title = "^$"; };
      no_focus = true;
      no_initial_focus = true;
      float = true;
      size = "0 0";
      move = "-1000 -1000";
    }

    # Slack - Handle context menus and dropdowns
    {
      name = "slack-context-menus";
      match = { class = "^(Slack)$"; title = "^(Context Menu)$"; };
      float = true;
      no_focus = true;
      size = "0 0";
    }
  ];
in
{
  # The per-user options are declared in ./options-user.nix, beside this file.
  config = mkIf anyUserGraphical {
    home-manager.users =
      mapAttrs
        (
          _name: userCfg:
            let
              # Get user-level hyprland config (with mynixos opinionated defaults)
              userHyprland = userCfg.apps.graphical.windowManagers.hyprland or { };

              # Get browser/terminal from environment API (single source of truth)
              browserApp = userCfg.environment.BROWSER or null;
              terminalApp = userCfg.environment.TERMINAL or null;

              # Derive command paths from packages
              # Falls back to opinionated defaults if environment not set
              browserCmd =
                if browserApp != null && (browserApp.enable or false) then
                  browserApp.package.meta.mainProgram or browserApp.package.pname or "brave"
                else
                  "brave";

              terminalCmd =
                if terminalApp != null && (terminalApp.enable or false) then
                  terminalApp.package.meta.mainProgram or terminalApp.package.pname or "wezterm"
                else
                  "wezterm";
            in
            mkIf (userCfg.graphical.enable && userHyprland.enable) {
              # GTK configuration. `theme`, `iconTheme` and `cursorTheme` are
              # left unset, so GTK apps use their built-in defaults -- vogix
              # themes terminal surfaces (alacritty, bat, btop, ripgrep, the
              # console palette) and has no GTK template.
              gtk = {
                enable = true;
              };

              # Swappy config for screenshots
              xdg.configFile."swappy/config".text = swappyConfig;

              # graphical-session-pre.target is systemd's designated slot for
              # session environment setup, and hyprland-session.target both
              # Wants= and is ordered After= it — so this runs on every raise of
              # the session, ahead of anything that needs a display. Type=oneshot
              # WITHOUT RemainAfterExit is deliberate: an "active (exited)"
              # oneshot is never re-run, which is exactly the once-only behaviour
              # that broke the session in the first place.
              systemd.user.services.hyprland-session-env = {
                Unit = {
                  Description = "Import the running Hyprland session environment into the user manager";
                  Before = [ "graphical-session-pre.target" "graphical-session.target" ];
                };
                Service = {
                  Type = "oneshot";
                  ExecStart = "${hyprlandSessionEnv}";
                };
                Install.WantedBy = [ "graphical-session-pre.target" ];
              };

              # Wanted by default.target rather than by the session, because the
              # case it exists for is a user manager that came up with no session
              # at all. It must not be reachable from hyprland-session.target, or
              # raising the target would wait on a job that raises the target.
              systemd.user.services.hyprland-session-recover = {
                Unit = {
                  Description = "Re-raise the Hyprland session when the user manager restarts under a live compositor";
                  After = [ "basic.target" ];
                };
                Service = {
                  Type = "oneshot";
                  ExecStart = "${hyprlandSessionRecover}";
                };
                Install.WantedBy = [ "default.target" ];
              };

              # Home packages
              home.packages = with pkgs; [
                # XDG portals are provided by programs.hyprland.enable in graphical.nix
                # Don't add xdg-desktop-portal-hyprland here to avoid conflicts
                brightnessctl
                # Wallpapers are the vogix shell's background layer (awww,
                # waypaper and swaybg went the way of waybar/mako/hyprlock).
                # The shell's weather widget and night light spawn these:
                wttrbar
                hyprsunset
                grimblast
                slurp
                swappy
                wl-clipboard
                cliphist
                udiskie
                vlc
                hyprpicker
                # wlogout is gone: the power menu is the vogix shell's
                # (`vogix desktop power`, Super+Escape).
                networkmanagerapplet
                pavucontrol
                pamixer
                playerctl
                gtk3
              ];

              # Hyprland configuration
              # Appearance + behavior handled by vogix hyprland module (via mkDefault)
              # This module provides infrastructure: monitor, env, autostart, app window rules
              wayland.windowManager.hyprland =
                let
                  modesEnabled = config.my.theming.vogix.enable or false;
                  configType = userHyprland.configType or "hyprlang";
                  isLua = configType == "lua";

                  # Call vogix's behavior generator directly so we can access its
                  # generated window-rule list and concatenate it with our own app
                  # rules below. Plain assignment of the rules key would otherwise
                  # clobber vogix's rules entirely — module-system priority markers
                  # (mkDefault / mkAfter) don't survive being nested inside a
                  # parent attrset assignment here, so list concatenation has to be
                  # explicit at this layer. `{}` as the behavior config = "use
                  # defaults" (see vogix/nix/modules/behavior/default.nix mergeOr).
                  vogixBehaviorOutput =
                    if !modesEnabled then { settings = { }; }
                    else if isLua then behaviorModule.mkHyprlandLuaConfig { }
                    else behaviorModule.mkHyprlandConfig { };
                  vogixWindowrules = vogixBehaviorOutput.settings.windowrule or [ ];
                  vogixWindowRulesLua = vogixBehaviorOutput.settings.window_rule or [ ];

                  # exec-once commands for the Lua start hook: hl.exec_cmd
                  # spawns detached already, so shell `&` suffixes are stripped.
                  luaStartupCommands = map (c: trim (removeSuffix "&" (trim c))) autostart;

                  # Infrastructure settings (always applied, overrides vogix
                  # defaults except for the window rules, where both lists are
                  # concatenated so vogix-generated rules — e.g. the
                  # vogix-console floating overlay — aren't silently dropped).
                  # The Lua branch carries the HM Lua shapes: hl.monitor /
                  # hl.env tables, exec-once as an hl.on("hyprland.start")
                  # closure, hl.window_rule tables.
                  infraSettings =
                    if isLua then {
                      # hl.monitor's `scale` is a STRING-typed field ("1",
                      # "1.5", "auto" — Hyprland 0.56.2 MONITOR_FIELDS,
                      # LuaBindingsConfigRules.cpp); a bare number only passes
                      # via lua_isstring coercion, so keep the quoted form.
                      monitor = [{ output = ""; mode = "highres"; position = "auto"; scale = "1"; }];
                      env = [
                        { _args = [ "TERMINAL" terminalCmd ]; }
                        { _args = [ "BROWSER" browserCmd ]; }
                        { _args = [ "COLORTERM" "truecolor" ]; }
                      ];
                      on = [
                        {
                          _args = [
                            "hyprland.start"
                            (mkLuaInline (
                              "function()\n"
                              + concatMapStrings (c: "  hl.exec_cmd(${luaLib.luaStr c})\n") luaStartupCommands
                              + "end"
                            ))
                          ];
                        }
                      ];
                      window_rule = vogixWindowRulesLua ++ windowRulesLua;
                    } else {
                      inherit (environment) monitor;
                      env = [
                        "TERMINAL,${terminalCmd}"
                        "BROWSER,${browserCmd}"
                        "COLORTERM,truecolor"
                      ];
                      exec-once = autostart;
                      windowrule = vogixWindowrules ++ windowRules;
                    };

                  # Fallback: when vogix is disabled, use legacy hardcoded config
                  fallbackSettings = lib.optionalAttrs (!modesEnabled) (
                    let
                      generalCfg = mkGeneral userHyprland;
                      decorationsCfg = mkDecorations userHyprland;
                      blurCfg = mkDecorationBlur userHyprland;
                      animationsCfg = mkAnimations userHyprland;
                      decorationSettings = {
                        inherit (decorationsCfg) active_opacity inactive_opacity fullscreen_opacity rounding dim_inactive dim_strength;
                        blur = { inherit (blurCfg) enabled brightness size; };
                      };
                    in
                    if isLua then {
                      bind = mkLuaBinds { inherit browserCmd terminalCmd; };
                      curve = [ (luaLib.parseBezier animationBezier) ];
                      animation = map luaLib.parseAnimationRule animationRules;
                      config = {
                        animations.enabled = userHyprland.animations_enabled;
                        binds = {
                          workspace_back_and_forth = false;
                          allow_workspace_cycles = false;
                        };
                        general = {
                          inherit (generalCfg) gaps_in gaps_out border_size layout;
                        };
                        input = mkInputLua userCfg.input;
                        inherit (layouts) dwindle master;
                        inherit misc group;
                        decoration = decorationSettings;
                      };
                    } else
                      (mkBindings { inherit browserCmd terminalCmd; })
                      // {
                        general = {
                          inherit (generalCfg) gaps_in gaps_out border_size layout;
                        };
                        input = mkInput userCfg.input;
                        inherit (layouts) dwindle master;
                        inherit misc group gestures;
                        animations = animationsCfg;
                        decoration = decorationSettings;
                      }
                  );
                in
                {
                  enable = true;
                  xwayland.enable = true;
                  # The engine follows the per-user option; "hyprlang" until a
                  # host flips to the Lua config (Hyprland 0.57 removes hyprlang).
                  inherit configType;
                  settings = lib.recursiveUpdate
                    (infraSettings // fallbackSettings)
                    (userHyprland.extraSettings or { });
                };
            }
        ) # End mkIf userHyprland.enable
        (activeUsers config.my.users);
  };
}
