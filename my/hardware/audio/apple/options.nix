# my.hardware.audio.darwin: the darwin-only half of the audio option, declared
# beside its implementation (./default.nix) and imported only by
# platforms/darwin.nix, so setting it on Linux is "does not exist" rather than a
# silent no-op. Type-only: my/hardware/options.nix carries the `hardware`
# submodule's default and description.

{ lib, ... }:

{
  hardware = lib.mkOption {
    type = lib.types.submodule {
      options.audio.darwin.maxSampleRate = lib.mkOption {
        description = ''
          Pin CoreAudio devices to their highest supported sample rate (macOS
          exposes no declarative mechanism for this).

          Higher is not automatically better — every consumer pays for it.
          For a spectrum visualiser it is wasted: cava's 22 kHz cutoff is
          already fully covered by 44.1 kHz (Nyquist).
        '';
        default = { };
        type = lib.types.submodule {
          options = {
            enable = lib.mkEnableOption "pinning CoreAudio devices to their maximum sample rate at login";

            exclude = lib.mkOption {
              type = lib.types.listOf lib.types.str;
              default = [ ];
              example = [ "Microphone" ];
              description = ''
                Skip devices whose name contains any of these, matched
                case-insensitively. Inputs are the usual candidates: a 96 kHz
                microphone doubles the data for voice with nothing to show.
              '';
            };
          };
        };
      };
    };
  };
}
