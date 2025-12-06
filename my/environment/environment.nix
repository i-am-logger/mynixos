{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.my.environment;
  motdCfg = cfg.motd;
in
{
  config = mkMerge [
    # MOTD configuration
    (mkIf motdCfg.enable {
      users.motd = motdCfg.content;
    })

    (mkIf cfg.enable (mkMerge [
      # Base environment configuration
      {
        # Environment variables (from mynixos defaults in flake.nix)
        # Use regular assignments (priority 100) to override nixpkgs mkDefault (priority 1000)
        # Note: BROWSER needs full path to binary for XDG to work correctly
        environment.variables = {
          EDITOR = "${cfg.editor}/bin/hx";
          VIEWER = "${cfg.editor}/bin/hx";
          BROWSER = "${cfg.browser}/bin/${cfg.browser.pname or "brave"}";
          DEFAULT_BROWSER = "${cfg.browser}/bin/${cfg.browser.pname or "brave"}";
        };

        environment.pathsToLink = [ "libexec" ];
        environment.sessionVariables.DEFAULT_BROWSER = mkDefault "${cfg.browser}/bin/${cfg.browser.pname or "brave"}";

        # XDG MIME defaults - using .desktop file pattern
        xdg.mime.defaultApplications = mkDefault {
          "text/html" = "${cfg.browser.pname or "brave"}-browser.desktop";
          "x-scheme-handler/http" = "${cfg.browser.pname or "brave"}-browser.desktop";
          "x-scheme-handler/https" = "${cfg.browser.pname or "brave"}-browser.desktop";
          "x-scheme-handler/about" = "${cfg.browser.pname or "brave"}-browser.desktop";
          "x-scheme-handler/unknown" = "${cfg.browser.pname or "brave"}-browser.desktop";
        };
      }

      # XDG portal configuration (for Wayland/Hyprland)
      (mkIf cfg.xdg.enable {
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
        WAYLAND_DISPLAY = "wayland-1";
      };

      services.dbus.enable = true;
      })

      # Common environment configuration (always enabled with environment feature)
      {
        # Common system services (opinionated)
        services.hardware.bolt.enable = lib.mkDefault true; # Thunderbolt support
        networking.networkmanager.enable = lib.mkDefault true;
        networking.wireless.enable = lib.mkDefault false; # Prefer NetworkManager

        # Dual-boot and filesystem support services
        services.udisks2.enable = mkDefault true; # Auto-mounting support
        services.timesyncd.enable = mkDefault true; # Network time sync

        # Locale and timezone (mynixos opinionated defaults)
        time.timeZone = mkDefault cfg.timezone;
        i18n.defaultLocale = mkDefault cfg.locale;
        i18n.extraLocaleSettings = mkDefault {
          LC_ADDRESS = cfg.locale;
          LC_IDENTIFICATION = cfg.locale;
          LC_MEASUREMENT = cfg.locale;
          LC_MONETARY = cfg.locale;
          LC_NAME = cfg.locale;
          LC_NUMERIC = cfg.locale;
          LC_PAPER = cfg.locale;
          LC_TELEPHONE = cfg.locale;
          LC_TIME = cfg.locale;
        };

        # Keyboard layout (mynixos opinionated defaults)
        services.xserver.xkb = {
          layout = mkDefault cfg.keyboardLayout;
          variant = mkDefault "";
        };

        # Opinionated stateVersion - using 25.05 as baseline (can be overridden)
        system.stateVersion = lib.mkDefault "25.05";
      }

      # Set home.stateVersion for all users (opinionated)
      {
        home-manager.users = mapAttrs
          (name: userCfg: {
            home.stateVersion = lib.mkDefault "25.05";
          })
          config.my.users;
      }
    ]))
  ];
}
