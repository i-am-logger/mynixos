{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.my.hardware.audio;
in
{
  config = mkIf (cfg.enable) {
    # PipeWire audio configuration

    # Disable PulseAudio in favor of PipeWire
    services.pulseaudio.enable = false;

    # Enable RealtimeKit for low-latency audio
    security.rtkit.enable = true;

    # PipeWire audio server with full feature set
    services.pipewire = {
      enable = true;
      audio.enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
      jack.enable = true;
      wireplumber.enable = true;
    };

    # Add users to audio group
    users.users = mapAttrs
      (name: userCfg: {
        extraGroups = [ "audio" ];
      })
      (filterAttrs (name: userCfg: userCfg.fullName or null != null) config.my.users);

    # Audio utilities
    environment.systemPackages = with pkgs; [
      alsa-tools
      alsa-utils
    ];
  };
}
