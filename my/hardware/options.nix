# Hardware options that mean something on BOTH platforms.
#
# cpu/gpu are metadata a host states about itself (my/infra/github-runner reads
# `hardware.gpu`); audio is the Apple sample-rate agent. Everything vendor- or
# bus-specific is declared next to its implementation instead --
# my/hardware/{bluetooth,motherboards,cooling,peripherals,laptops/*}/options.nix
# -- so it exists only on the platform that can act on it.
#
# This file carries `default` and `description` for the `hardware` submodule;
# the per-implementation files are type-only, because two declarations may merge
# but only one may carry those.

{ lib, ... }:

{
  hardware = lib.mkOption {
    type = lib.types.submodule {
      options = {
        # "apple" means Apple Silicon, where the CPU and GPU are the same die.
        # There is deliberately no my/hardware/{cpu,gpu}/apple implementation to
        # go with it: macOS owns those drivers entirely, so the module would be
        # empty. The value is still worth declaring -- it is how a host states
        # what it is, and my/infra/github-runner already reads `hardware.gpu` as
        # metadata.
        cpu = lib.mkOption {
          type = lib.types.nullOr (lib.types.enum [ "amd" "intel" "apple" ]);
          default = null;
          description = "CPU vendor";
        };

        gpu = lib.mkOption {
          type = lib.types.nullOr (lib.types.enum [ "amd" "nvidia" "intel" "apple" ]);
          default = null;
          description = "GPU vendor";
        };




        audio = {
          maxSampleRate = lib.mkOption {
            description = ''
              Pin CoreAudio devices to their highest supported sample rate
              (darwin only; macOS exposes no declarative mechanism for this).

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

          enable = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "Enable audio";
          };
        };




      };
    };
    default = { };
    description = "Hardware configuration";
  };
}
