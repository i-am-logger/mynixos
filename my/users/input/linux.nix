# The input method server, on Linux (my.users.<n>.input.inputMethod).
#
# Per user, through home-manager's i18n.inputMethod: its fcitx5-daemon unit is
# WantedBy graphical-session.target, which hyprland-session.target binds, so
# the server starts with the session and needs no exec-once. Hyprland does not
# run XDG autostart, which is the only start NixOS's own i18n.inputMethod gives.
#
# waylandFrontend: apps reach fcitx5 over text-input-v3 and the compositor's
# input-method-v2, so GTK_IM_MODULE/QT_IM_MODULE stay unset, as Wayland wants.
#
# The settings are NOT written through i18n.inputMethod.fcitx5.settings: any
# value there turns the whole of ~/.config/fcitx5 into one store link, so
# fcitx5 could not save its own profile and the directory could not be
# persisted. mynixos owns two files in it, each a link fcitx5 cannot save
# over: `config` (the hotkeys) and conf/classicui.conf (the popup). For a
# vogix user the latter carries Theme=vogix, naming the theme vogix links into
# ~/.local/share/fcitx5/themes/vogix (and reloads over D-Bus); UseDarkTheme
# stays off, since with the portal reporting prefer-dark it would swap in
# fcitx5's own dark theme in place of vogix's, which already follows the
# variant.
#
# Imported only by platforms/linux.nix.
{ activeUsers, config, lib, ... }:

with lib;

let
  users = activeUsers config.my.users;
  isFcitx5 = userCfg: userCfg.input.inputMethod.type == "fcitx5";
  fcitx5Users = filterAttrs (_: isFcitx5) users;

  # The shell sizes its body text in pixels (graphical.fontSize, else the
  # vogix desktop's 21); classicui takes points. At the desktop's 96 dpi a
  # point is 4/3 px, rounded to the nearest point: 21 px is 16 pt.
  popupPt = userCfg:
    let px = if userCfg.graphical.fontSize or null != null then userCfg.graphical.fontSize else 21;
    in (px * 3 + 2) / 4;
in
{
  config = mkIf (fcitx5Users != { }) {
    assertions = mapAttrsToList
      (name: userCfg: {
        assertion = userCfg.graphical.enable;
        message = "my.users.${name}.input.inputMethod.type = \"fcitx5\" needs my.users.${name}.graphical.enable: the server runs in the graphical session.";
      })
      fcitx5Users;

    home-manager.users = mapAttrs
      (_name: userCfg: hm: {
        i18n.inputMethod = {
          enable = true;
          type = "fcitx5";
          fcitx5 = {
            waylandFrontend = true;
            inherit (userCfg.input.inputMethod) addons;
          };
        };

        # fcitx5 reads its config once, at start, so a switch that changes
        # the files below restarts it: naming them in the unit changes the
        # unit with them, and home-manager restarts a changed unit.
        systemd.user.services.fcitx5-daemon.Unit.X-Restart-Triggers =
          map (f: "${hm.config.xdg.configFile.${f}.source}")
            [ "fcitx5/config" "fcitx5/conf/wayland.conf" "fcitx5/conf/xcb.conf" "fcitx5/conf/classicui.conf" ];

        # No hotkey switches the input method while the profile holds only a
        # keyboard: Ctrl+Space is NUL in a terminal (emacs set-mark, zsh and
        # tmux bindings), Shift_L alone is ordinary typing, and Super+Space
        # is the compositor's. EN/HE is XKB's, through the shell's layout
        # chip. A trigger is chosen with vogix's keymap once a composing
        # engine (rime, mozc) is added. An empty section is an empty list;
        # an absent one would be fcitx5's default.
        #
        # The tray item is off too: it can only report fcitx5's own keyboard
        # IM, so beside the shell's layout chip it is a second indicator that
        # never agrees with the first.
        xdg.configFile = {
          "fcitx5/config".text = ''
            [Hotkey/TriggerKeys]

            [Hotkey/AltTriggerKeys]

            [Hotkey/EnumerateGroupForwardKeys]

            [Hotkey/EnumerateGroupBackwardKeys]

            [Behavior/DisabledAddons]
            0=notificationitem
          '';

          # XKB keeps the layout: fcitx5 may not push its group's layout onto
          # the compositor (wayland) or onto XWayland's X server (xcb), where
          # it would replace the person's layouts with keyboard-us's.
          "fcitx5/conf/wayland.conf".text = ''
            Allow Overriding System XKB Settings=False
          '';
          "fcitx5/conf/xcb.conf".text = ''
            Allow Overriding System XKB Settings=False
          '';

          # The candidate popup reads as the shell's: its font (theme.conf
          # cannot carry one), and for a vogix user its theme.
          "fcitx5/conf/classicui.conf".text = ''
            Font="Fira Code Nerd Font ${toString (popupPt userCfg)}"
            MenuFont="Fira Code Nerd Font ${toString (popupPt userCfg)}"
          '' + optionalString (userCfg.theming.vogix.enable or false) ''
            Theme=vogix
            UseDarkTheme=False
            UseAccentColor=False
          '';
        };
      })
      fcitx5Users;

    # fcitx5's profile and its own settings, and the user dictionaries and
    # themes under share.
    my.system.persistence.features.userDirectories = [
      ".config/fcitx5"
      ".local/share/fcitx5"
    ];
  };
}
