{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.my.features.streaming;

  # mynixos opinionated defaults for streaming
  defaults = {
    obs = true; # OBS enabled by default when system streaming is enabled
  };
in
{
  config = mkIf cfg.enable (mkMerge [
    # Base streaming configuration
    {
      security.polkit.enable = true;

      # Allow users group to run modprobe (needed for v4l2loopback and other kernel modules)
      security.polkit.extraConfig = ''
        polkit.addRule(function(action, subject) {
            if (action.id == "org.freedesktop.policykit.exec" &&
                action.lookup("program") == "/run/current-system/sw/bin/modprobe" &&
                subject.isInGroup("users")) {
                return polkit.Result.YES;
            }
        });
      '';

      services.usbmuxd.enable = true;

      # Add users to streaming-related groups
      users.users = mapAttrs
        (name: userCfg: {
          extraGroups = [ "udev" "usb" "audio" ];
        })
        (filterAttrs (name: userCfg: userCfg.fullName or null != null) config.my.users);
    }

    # v4l2loopback kernel module for virtual webcam (conditional)
    (mkIf cfg.v4l2loopback.enable {
      boot.kernelModules = [ "v4l2loopback" ];

      boot.extraModulePackages = [
        config.boot.kernelPackages.v4l2loopback
      ];

      boot.extraModprobeConfig = ''
        options v4l2loopback devices=1 video_nr=1 card_label="My OBS Virt Cam" exclusive_caps=1
      '';
    })

    # OBS Studio with plugins (per-user configuration)
    {
      home-manager.users = mapAttrs
        (name: userCfg:
          let
            # Get user-level streaming config (with mynixos opinionated defaults)
            userStreaming = userCfg.features.streaming or { };
          in
          mkIf (userStreaming.obs or defaults.obs) {
            home.packages = with pkgs; [
              ffmpeg-full
              twitch-tui # twitch chat in terminal
              streamlink # streamlink for live videostream
            ];

            programs.obs-studio = {
              enable = true;
              plugins = with pkgs.obs-studio-plugins; [
                wlrobs
                obs-teleport
                obs-tuna
                waveform
                obs-text-pthread # rich text source plugin for custom text overlays
                advanced-scene-switcher # automated scene switcher with hotkey support
                obs-websocket # WebSocket support for Stream Deck integration (legacy support)
              ];
            };
          })
        config.my.users;
    }

    # StreamDeck support
    (mkIf cfg.streamdeck.enable {
      # Add Stream Deck udev rules for hardware access
      services.udev.packages = [
        pkgs.streamdeck-ui
      ];

      # Enable udev rules for Stream Deck devices
      services.udev.extraRules = ''
        # Stream Deck Original
        SUBSYSTEM=="usb", ATTRS{idVendor}=="0fd9", ATTRS{idProduct}=="0060", MODE="0664", GROUP="users"
        # Stream Deck Mini
        SUBSYSTEM=="usb", ATTRS{idVendor}=="0fd9", ATTRS{idProduct}=="0063", MODE="0664", GROUP="users"
        # Stream Deck XL
        SUBSYSTEM=="usb", ATTRS{idVendor}=="0fd9", ATTRS{idProduct}=="006c", MODE="0664", GROUP="users"
        # Stream Deck V2
        SUBSYSTEM=="usb", ATTRS{idVendor}=="0fd9", ATTRS{idProduct}=="006d", MODE="0664", GROUP="users"
        # Stream Deck MK.2
        SUBSYSTEM=="usb", ATTRS{idVendor}=="0fd9", ATTRS{idProduct}=="0080", MODE="0664", GROUP="users"
        # Stream Deck Plus
        SUBSYSTEM=="usb", ATTRS{idVendor}=="0fd9", ATTRS{idProduct}=="0084", MODE="0664", GROUP="users"
      '';

      # Ensure the user is in the required groups
      users.groups.streamdeck = { };

      # Add streamdeck-ui with Qt platform fixes (applied to all users)
      home-manager.users = mapAttrs
        (name: userCfg: {
          home.packages = with pkgs; [
            streamdeck-ui
            # Qt platform dependencies
            libsForQt5.qt5.qtwayland
            qt6.qtwayland
          ];
        })
        config.my.users;

      # Fix Qt platform plugin issues for streamdeck-ui
      environment.sessionVariables = {
        # Set Qt platform plugins path
        QT_QPA_PLATFORM_PLUGIN_PATH = "${pkgs.libsForQt5.qt5.qtbase.bin}/lib/qt-${pkgs.libsForQt5.qt5.qtbase.version}/plugins/platforms:${pkgs.qt6.qtbase}/lib/qt-6/plugins/platforms";
        # Prefer Wayland but fallback to xcb
        QT_QPA_PLATFORM = "wayland;xcb";
        # Enable Qt logging for debugging
        QT_LOGGING_RULES = "qt.qpa.plugin.debug=false";
      };

      # Disable streamdeck-ui system service if it's causing issues
      # Users should run it manually from their desktop session
      systemd.user.services.streamdeck-ui = {
        enable = false;
      };
    })
  ]);
}
