{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.my.features.environment;
in
{
  config = mkIf cfg.enable (mkMerge [
    # Base environment configuration
    {
      # Environment variables (from mynixos defaults in flake.nix)
      environment.variables = {
        EDITOR = mkDefault "${cfg.editor}/bin/hx";
        VIEWER = mkDefault "${cfg.editor}/bin/hx";
        BROWSER = mkDefault cfg.browser;
        DEFAULT_BROWSER = mkDefault cfg.browser;
      };

      environment.pathsToLink = [ "libexec" ];
      environment.sessionVariables.DEFAULT_BROWSER = mkDefault cfg.browser;

      # XDG MIME defaults
      xdg.mime.defaultApplications = mkDefault {
        "text/html" = cfg.browser;
        "x-scheme-handler/http" = cfg.browser;
        "x-scheme-handler/https" = cfg.browser;
        "x-scheme-handler/about" = cfg.browser;
        "x-scheme-handler/unknown" = cfg.browser;
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

      # Common system services (opinionated)
      services.hardware.bolt.enable = lib.mkDefault true; # Thunderbolt support
      networking.networkmanager.enable = lib.mkDefault true;
      networking.wireless.enable = lib.mkDefault false; # Prefer NetworkManager

      # Dual-boot and filesystem support services
      services.udisks2.enable = mkDefault true; # Auto-mounting support
      services.timesyncd.enable = mkDefault true; # Network time sync
      services.fstrim.enable = mkDefault true; # SSD optimization

      # Locale and timezone (mynixos opinionated defaults)
      time.timeZone = mkDefault (cfg.timezone or defaults.timezone);
      i18n.defaultLocale = mkDefault (cfg.locale or defaults.locale);
      i18n.extraLocaleSettings = mkDefault {
        LC_ADDRESS = cfg.locale or defaults.locale;
        LC_IDENTIFICATION = cfg.locale or defaults.locale;
        LC_MEASUREMENT = cfg.locale or defaults.locale;
        LC_MONETARY = cfg.locale or defaults.locale;
        LC_NAME = cfg.locale or defaults.locale;
        LC_NUMERIC = cfg.locale or defaults.locale;
        LC_PAPER = cfg.locale or defaults.locale;
        LC_TELEPHONE = cfg.locale or defaults.locale;
        LC_TIME = cfg.locale or defaults.locale;
      };

      # Keyboard layout (mynixos opinionated defaults)
      services.xserver.xkb = {
        layout = mkDefault (cfg.keyboardLayout or defaults.keyboardLayout);
        variant = mkDefault "";
      };

      # Opinionated stateVersion - using 25.05 as baseline (can be overridden)
      system.stateVersion = lib.mkDefault "25.05";
    })

    # Set home.stateVersion for all users (opinionated)
    {
      home-manager.users = mapAttrs
        (name: userCfg: {
          home.stateVersion = lib.mkDefault "25.05";
        })
        config.my.users;
    }
  ]);
}
