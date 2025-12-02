{ config, lib, pkgs, ... }:

{
  # Realtek audio chipset driver configuration

  # Disable PulseAudio in favor of PipeWire
  services.pulseaudio.enable = false;

  # Enable RealtimeKit for low-latency audio
  security.rtkit.enable = true;

  # PipeWire audio server
  services.pipewire = {
    enable = true;
    audio.enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };
}
