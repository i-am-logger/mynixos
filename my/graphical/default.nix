{ activeUsers
, config
, lib
, pkgs
, ...
}:

with lib;

let
  # Auto-enable graphical when any user has graphical.enable = true
  anyUserGraphical = any (userCfg: userCfg.graphical.enable or false) (attrValues config.my.users);
  # Hyprland is the per-user app switch (on by default for graphical users),
  # and the system half follows it rather than graphical.enable alone.
  anyUserHyprland = any
    (userCfg: userCfg.graphical.enable && userCfg.apps.graphical.windowManagers.hyprland.enable)
    (attrValues config.my.users);
in
{
  config = mkMerge [
    # Set read-only system flag
    { my.graphical.enable = mkDefault anyUserGraphical; }

    # Feature configuration
    (mkIf config.my.graphical.enable (mkMerge [
      # System-level Hyprland, for the users who run it
      (mkIf anyUserHyprland {
        systemd.tmpfiles.rules = [
          "d /tmp/hypr 1777 root root -"
        ];

        programs.hyprland = {
          enable = true;
          xwayland.enable = true;
        };

        # Hyprland's package runs unwrapped here (nixpkgs-fixes/lean.nix), so
        # the dialogs it spawns (not-responding, update) and the lspci its
        # systeminfo reads come from the system PATH.
        environment.systemPackages = [ pkgs.hyprland-guiutils pkgs.pciutils ];

        # The hyprland package ships TWO session files, and programs.hyprland
        # registers both — including hyprland-uwsm.desktop, whose `uwsm
        # start` dies instantly on this fleet (uwsm is not configured; the
        # session opened and closed within a second, bouncing the login
        # straight back to the greeter). Register ONLY the plain Hyprland
        # session so a greeter can never pick the broken one.
        services.displayManager.sessionPackages = mkForce [
          (pkgs.runCommand "hyprland-session-only"
            { passthru.providedSessions = [ "hyprland" ]; }
            ''
              mkdir -p $out/share/wayland-sessions
              ln -s ${config.programs.hyprland.package}/share/wayland-sessions/hyprland.desktop \
                $out/share/wayland-sessions/hyprland.desktop
            '')
        ];
      })

      # Base desktop configuration
      {
        # nixpkgs' graphical-desktop turns speech-dispatcher on for every
        # desktop: espeak, mbrola and ~650 MiB of voices. No mynixos host runs a
        # screen reader; services.orca (or setting this) brings it back.
        # mkOverride 900: above nixpkgs' own mkDefault, below a plain host setting.
        services.speechd.enable = mkOverride 900 false;

        # vogix writes org.gnome.desktop.interface color-scheme on every theme
        # apply; xdg-desktop-portal-gtk serves it as the portal's
        # color-scheme setting, which is what Chromium-family browsers follow.
        # Without dconf the write has nowhere to land.
        programs.dconf.enable = true;

        # No GNOME keyring: secrets live in a GPG-backed pass store (with a
        # security key, in its card), and browsers keep their own store
        # (Brave runs with --password-store=basic). All three are needed --
        # the service, its PAM hook at login, and the variables that stop
        # libraries starting one on demand. glib-networking stays, for TLS in
        # GLib apps, which gnome-keyring used to pull in.
        services.gnome = {
          gnome-keyring.enable = false;
          glib-networking.enable = true;
        };
        security.pam.services = {
          login.enableGnomeKeyring = false;
          gdm.enableGnomeKeyring = false;
        };
        environment.sessionVariables = {
          GNOME_KEYRING_CONTROL = "";
          DISABLE_GNOME_KEYRING = "1";
        };

        # The login itself (display manager, greeter look, autologin) is
        # my.environment.login — implemented in ./login, beside this file.
      }

      # XDG portal configuration (for Wayland/Hyprland)
      (mkIf config.my.environment.xdg.enable {
        xdg.portal = {
          enable = true;
          configPackages = [ pkgs.xdg-desktop-portal-gtk ];
          xdgOpenUsePortal = true;
          extraPortals = [
            pkgs.xdg-desktop-portal-hyprland
            pkgs.xdg-desktop-portal-gtk
          ];
          config = {
            common = {
              default = [
                "hyprland"
                "gtk"
              ];
              "org.freedesktop.impl.portal.Settings" = [
                "gtk"
              ];
            };
            hyprland = {
              default = [
                "hyprland"
                "gtk"
              ];
              "org.freedesktop.impl.portal.Settings" = [
                "gtk"
              ];
            };
          };
        };

        environment.systemPackages = with pkgs; [
          qt6.qtwayland
        ];

        environment.sessionVariables = {
          NIXOS_OZONE_WL = "1"; # For Electron apps
          XDG_CURRENT_DESKTOP = "Hyprland";
          XDG_SESSION_TYPE = "wayland";
          XDG_SESSION_DESKTOP = "Hyprland";
          GDK_BACKEND = "wayland";
          QT_QPA_PLATFORM = "wayland;xcb";
          QT_WAYLAND_DISABLE_WINDOWDECORATION = "1";
          MOZ_ENABLE_WAYLAND = "1";
          # NOTE: do NOT set WAYLAND_DISPLAY here. It is assigned by the
          # compositor at runtime (Hyprland creates wayland-0/-1/… and exports
          # it; the session then runs `systemctl --user import-environment
          # WAYLAND_DISPLAY` + `dbus-update-activation-environment`). Forcing it
          # globally makes EVERY session — including the GDM greeter's mutter —
          # see WAYLAND_DISPLAY before any socket exists, so the compositor
          # tries to run *nested* against a non-existent display and bails
          # ("GdmDisplay: Session never registered, failing" / "Unable to run
          # session"). Harmless on older GNOME, fatal under GNOME 50.
        };

        services.dbus.enable = true;
      })

      # Common graphical configuration
      {
        # Notifications are the vogix shell's own server (mako is gone from
        # the fleet — the shell replaced it, per surface, like waybar).

        # GPU and video nodes for the users who run a desktop, and only them.
        # No `input`: it reads every /dev/input node (a keylogger's access),
        # and seat devices already come through logind's uaccess. vogix's
        # input engine, which does grab keyboards, adds `input` and `uinput`
        # to its own users itself. No `gpu`: no such group exists.
        users.users = mapAttrs
          (_name: _userCfg: {
            extraGroups = [ "video" "render" ];
          })
          (filterAttrs (_: userCfg: userCfg.graphical.enable) (activeUsers config.my.users));
      }

      # Audio tools are now in my.hardware.audio, not in graphical

      # Persistence configuration
      {
        my.system.persistence.features = {
          systemDirectories = [
            "/var/lib/gnome"
            "/var/lib/AccountsService"
            "/var/lib/colord"
            "/var/lib/power-profiles-daemon"
            "/var/lib/upower"
          ];
          userDirectories = [
            ".mozilla"
            # swappy's save_dir (./hyprland): mynixos chose the path, so it
            # declares it; the rest of ~/Pictures is the person's own.
            "Pictures/screenshots"
          ];
        };
      }
    ]))
  ];
}
