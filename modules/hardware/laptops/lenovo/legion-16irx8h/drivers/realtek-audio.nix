{ config, lib, pkgs, ... }:

{
  # Realtek ALC3287 audio chipset driver configuration
  # Lenovo Legion Pro 7 16IRX8H specific

  # Audio configuration is handled by the generic realtek audio module
  # This file contains only hardware-specific fixes for this laptop

  # Hardware fix: Unmute speaker on boot
  # The speaker is muted by default on this specific hardware
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
