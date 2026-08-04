# Audio device sample rates on darwin.
#
# There is no declarative mechanism for this in macOS: no `defaults` key, no
# nix-darwin option (the module tree has none), and no packaged CLI that does it
# — switchaudio-osx only changes which device is *default*. Audio MIDI Setup
# drives the CoreAudio API, so packages/audio-max-rate does the same.
#
# Applied by a launchd user agent at login rather than an activation script,
# because CoreAudio devices belong to the logged-in user's audio session and are
# not all present at activation time.
#
# WORTH KNOWING: a higher rate is not automatically better. Every consumer pays
# for it — more samples per second to process for the same content. For a
# spectrum visualiser it is strictly wasted: cava's higher_cutoff_freq of 22 kHz
# is already fully covered by 44.1 kHz (Nyquist), so anything above that adds
# FFT work and no information. Raising an input device is the least useful case
# of all; `exclude` exists for that.
{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.my.hardware.audio.maxSampleRate;
  audioMaxRate = pkgs.callPackage ../../../../packages/audio-max-rate { };
in
{
  config = mkIf cfg.enable {
    launchd.user.agents.audio-max-rate = {
      serviceConfig = {
        Label = "org.mynixos.audio-max-rate";
        RunAtLoad = true;
        KeepAlive = false;
        StandardOutPath = "/tmp/audio-max-rate.log";
        StandardErrorPath = "/tmp/audio-max-rate.log";
      };
      command = concatStringsSep " " (
        [ (getExe audioMaxRate) ]
        ++ map (x: "--exclude ${escapeShellArg x}") cfg.exclude
      );
    };

    # Also available interactively, to re-apply after plugging in a DAC.
    environment.systemPackages = [ audioMaxRate ];
  };
}
