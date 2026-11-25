# Power supply profiles.
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
        powerSupplies = {
          corsair = {
            hx1200i = {
              enable = lib.mkEnableOption "Corsair HX1200i Series 2025 power supply (USB 1b1c:1c27) telemetry";
            };
          };
        };
      };
    };
  };
}
