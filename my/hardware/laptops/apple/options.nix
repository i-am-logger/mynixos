# Apple laptop profiles.
#
# Declared beside the implementation rather than in the central
# my/hardware/options.nix, so the option exists only where something reads it.
# platforms/darwin.nix imports this; the other platform does not, so setting it
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
        laptops = {
          apple = {
            macbook-pro-m5-max = {
              enable = lib.mkEnableOption "Apple MacBook Pro (M5 Max)";

              biometrics = {
                enable = lib.mkOption {
                  type = lib.types.bool;
                  default = true;
                  description = "Enable Touch ID (the sensor is built into the keyboard)";
                };
              };

              audio = {
                maxSampleRate = lib.mkOption {
                  type = lib.types.bool;
                  default = false;
                  description = ''
                    Pin CoreAudio devices to their highest supported rate at
                    login. Off by default: higher is not automatically better,
                    and every audio consumer pays for it.
                  '';
                };
              };
            };
          };
        };
      };
    };
  };
}
