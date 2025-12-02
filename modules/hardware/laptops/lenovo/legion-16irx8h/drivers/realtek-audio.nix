{ config, lib, pkgs, ... }:

{
  # Realtek ALC3287 audio chipset driver configuration
  # Lenovo Legion Pro 7 16IRX8H specific

  # Disable PulseAudio in favor of PipeWire
  services.pulseaudio.enable = false;

  # Enable RealtimeKit for low-latency audio
  security.rtkit.enable = true;

  # PipeWire audio server with JACK support
  services.pipewire = {
    enable = true;
    audio.enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    jack.enable = true;
    wireplumber.enable = true;
  };

  # Hardware fix: Unmute speaker on boot
  # The speaker is muted by default on this hardware
  systemd.services.fix-audio-speaker = {
    description = "Unmute Speaker on Boot (Legion hardware fix)";
    wantedBy = [ "multi-user.target" ];
    after = [ "sound.target" ];
    script = ''
      ${pkgs.alsa-utils}/bin/amixer -c 0 sset "Speaker" unmute || true
    '';
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
  };
}
