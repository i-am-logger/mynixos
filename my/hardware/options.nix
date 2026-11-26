# Hardware options that mean something on BOTH platforms.
#
# cpu/gpu are metadata a host states about itself (my/infra/github-runner reads
# `hardware.gpu`); audio.enable is PipeWire on Linux. Everything vendor- or
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
