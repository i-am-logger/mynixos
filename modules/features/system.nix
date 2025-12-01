{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.my.features.system;

  # Get list of all user names from my.features.users
  userNames = attrNames config.my.features.users;
in
{
  config = mkIf cfg.enable (mkMerge [
    # Base system configuration
    {
      # Console configuration
      console = {
        enable = true;
        earlySetup = true;
        useXkbConfig = true;
      };

      # Boot configuration
      boot.loader.grub.configurationLimit = 100;
      boot.tmp.cleanOnBoot = true;

      # Nix configuration
      nix = {
        settings = {
          max-jobs = "auto";
          cores = 0; # auto detect
          build-cores = 0;
          sandbox = true;
          system-features = [
            "big-parallel"
          ];

          extra-platforms = [
            "x86_64-linux"
          ];

          # Add all users as trusted
          trusted-users = [ "root" ] ++ userNames;

          substituters = [
            "https://cache.nixos.org/"
          ];

          auto-optimise-store = true;
        };

        gc = {
          automatic = true;
          dates = "weekly";
          options = "--delete-older-than 7d";
        };

        package = pkgs.nixVersions.latest;

        extraOptions = ''
          experimental-features = nix-command flakes auto-allocate-uids
          keep-outputs          = false
          keep-derivations      = false
          extra-substituters = https://devenv.cachix.org
          extra-trusted-public-keys = devenv.cachix.org-1:w1cLUi8dv3hnoSPGAuibQv+f9TZLr6cv/Hm9XgU50cw=
        '';
      };

      # Environment variables
      environment.variables = {
        EDITOR = "hx";
        VIEWER = "hx";
        BROWSER = "brave";
        DEFAULT_BROWSER = "brave";
      };

      environment.pathsToLink = [ "libexec" ];
      environment.sessionVariables.DEFAULT_BROWSER = "brave";

      # XDG MIME defaults
      xdg.mime.defaultApplications = {
        "text/html" = "brave";
        "x-scheme-handler/http" = "brave";
        "x-scheme-handler/https" = "brave";
        "x-scheme-handler/about" = "brave";
        "x-scheme-handler/unknown" = "brave";
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
  ]);
}
