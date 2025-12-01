{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.my.hardware.audio;
in
{
  config = mkIf (cfg.enable) {
    # Realtek audio driver configuration

    # Enable sound with pipewire
    hardware.pulseaudio.enable = false;
    security.rtkit.enable = true;
    services.pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
      jack.enable = true;
    };
  };
}
