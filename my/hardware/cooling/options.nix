# Cooling hardware profiles.
#
# Declared beside the implementation rather than in the central
# my/hardware/options.nix, so the option exists only where something reads it.
# platforms/linux.nix imports this; the other platform does not, so setting it
# there is the module system's own "does not exist" error rather than silence.
#
# Type-only: my/hardware/options.nix carries `default` and `description` for the
# `hardware` submodule. Two declarations may merge, but only one may carry those,
# or it is a conflicting declaration rather than a merge.

{ lib, ... }:

{
  hardware = lib.mkOption {
    type = lib.types.submodule {
      options = {
        cooling = {
          nzxt = {
            kraken-elite-rgb = {
              elite-240-rgb = {
                enable = lib.mkEnableOption "NZXT Kraken Elite 240 RGB AIO cooler";

                lcd = {
                  enable = lib.mkOption {
                    type = lib.types.bool;
                    default = true;
                    description = "Enable LCD screen support";
                  };

                  brightness = lib.mkOption {
                    type = lib.types.ints.between 0 100;
                    default = 100;
                    description = "LCD screen brightness (0-100)";
                  };
                };

                rgb = {
                  enable = lib.mkOption {
                    type = lib.types.bool;
                    default = true;
                    description = "Enable RGB ring around LCD screen";
                  };
                };

                liquidctl = {
                  enable = lib.mkOption {
                    type = lib.types.bool;
                    default = true;
                    description = "Install liquidctl CLI tool";
                  };

                  autoInitialize = lib.mkOption {
                    type = lib.types.bool;
                    default = false;
                    description = "Automatically run liquidctl initialize on boot";
                  };
                };

                monitoring = {
                  enable = lib.mkOption {
                    type = lib.types.bool;
                    default = true;
                    description = "Install lm_sensors for monitoring";
                  };
                };
              };
            };
          };
        };
      };
    };
  };
}
