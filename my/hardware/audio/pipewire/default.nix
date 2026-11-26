# my.hardware.audio on Linux: PipeWire (with its PulseAudio, ALSA and JACK
# faces) and RealtimeKit. macOS needs no audio server; its one audio setting,
# audio.darwin.maxSampleRate, is ../apple. Machine-specific fixes stay with
# their machine: the Legion's TAS2781 speaker unit is legion-16irx8h's.
{ activeUsers, config, lib, pkgs, ... }:

with lib;

let
  cfg = config.my.hardware.audio;
in
{
  config = mkIf cfg.enable {
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
      (_name: _userCfg: {
        extraGroups = [ "audio" ];
      })
      (activeUsers config.my.users);

    # Audio utilities
    environment.systemPackages = with pkgs; [
      # Not alsa-tools: its fltk GUIs pin the whole gcc toolchain (1.3 GiB).
      alsa-utils
    ];
  };
}
