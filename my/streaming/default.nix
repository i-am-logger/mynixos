{ activeUsers, config, lib, pkgs, ... }:

with lib;

let
  # Auto-enable streaming when any user has graphical.streaming.enable = true
  anyUserStreaming = any (userCfg: userCfg.graphical.streaming.enable or false) (attrValues config.my.users);

  # mynixos opinionated defaults for streaming
in
{
  config = mkMerge [
    # Set system flag
    { my.streaming.enable = mkDefault anyUserStreaming; }

    # Feature configuration
    (mkIf config.my.streaming.enable (mkMerge [
      # Base streaming configuration
      {
        # Enable polkit for streaming (mkDefault so security module can also enable it)
        security.polkit.enable = lib.mkDefault true;
        # No groups: `udev` and `usb` exist on no NixOS system, and `audio` is
        # my.hardware.audio's (with PipeWire and uaccess it only adds raw ALSA).
        # The virtual camera is a v4l2 node, which a seat's user reaches
        # through uaccess.
      }

      # OBS's virtual camera (v4l2loopback). It exists for OBS alone, so it
      # follows streaming rather than being a host switch of its own.
      {
        boot = {
          kernelModules = [ "v4l2loopback" ];
          extraModulePackages = [ config.boot.kernelPackages.v4l2loopback ];
          extraModprobeConfig = ''
            options v4l2loopback devices=1 video_nr=1 card_label="OBS Virtual Camera" exclusive_caps=1
          '';
        };
      }

      # OBS Studio with plugins (per-user configuration)
      {
        home-manager.users = mapAttrs
          (_name: userCfg:
            # Enable OBS for users with graphical.streaming.enable = true
            mkIf (userCfg.graphical.streaming.enable or false) {
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
          (activeUsers config.my.users);
      }

      # StreamDeck support moved to my.hardware.peripherals.elgato.streamdeck
      # Streaming users can enable it separately if they have the hardware
    ]))
  ];
}
