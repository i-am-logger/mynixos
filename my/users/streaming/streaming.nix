{ config, lib, pkgs, ... }:

with lib;

let
  # Auto-enable streaming when any user has streaming = true
  anyUserStreaming = any (userCfg: userCfg.streaming or false) (attrValues config.my.users);

  # mynixos opinionated defaults for streaming
  defaults = {
    obs = true; # OBS enabled by default when user streaming is enabled
  };
in
{
  config = mkIf anyUserStreaming (mkMerge [
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

    # Default to enable video.virtual when any user has streaming enabled
    # The actual kernel module configuration is in my/video/virtual.nix
    {
      my.video.virtual.enable = mkDefault true;
    }

    # OBS Studio with plugins (per-user configuration)
    {
      home-manager.users = mapAttrs
        (name: userCfg:
          # Enable OBS for users with streaming = true
          mkIf (userCfg.streaming or false) {
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

    # StreamDeck support moved to my.hardware.peripherals.elgato.streamdeck
    # Streaming users can enable it separately if they have the hardware
  ]);
}
