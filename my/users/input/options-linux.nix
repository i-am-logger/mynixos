# Pointer preferences that exist only on Linux.
#
# Loaded by platforms/linux.nix through mkOptionsModule, so this returns
# `{ users = mkOption ...; }` rather than the bare `{ options.input = ...; }`
# fragment ./options.nix uses. `types.submodule` declarations for the same option
# merge, so the two compose into one `my.users.<n>.input` submodule.
#
# accelSpeed is here rather than in ./options.nix because libinput's number and
# macOS's `com.apple.mouse.scaling` cannot be mapped onto each other:
#
#   * 0.0 means opposite things. libinput 0.0 is the device's own default, the
#     MIDDLE of its range. macOS 0.0 is the slowest curve, the BOTTOM of its range.
#   * negative means opposite things. libinput -1.0 is slowest but still
#     accelerated. macOS negative disables the acceleration filter entirely and
#     delivers raw deltas.
#   * neither value is a gain. They parameterise different curve models, so there
#     is no conversion that preserves feel.
#
# Declaring it here means a darwin host that sets it fails with "The option
# `my.users.logger.input.accelSpeed' does not exist" instead of silently getting
# a number that means something else.

{ lib, ... }:

{
  # Declares `type` only — no `default`, no `description`. Those are supplied by
  # ./options.nix, and repeating them here would be a duplicate declaration of
  # the same option rather than a merge. Same shape as
  # my/network/ssh-firewall/options.nix.
  users = lib.mkOption {
    type = lib.types.attrsOf (lib.types.submodule {
      options.input = lib.mkOption {
        type = lib.types.submodule {
          options = {
            accelSpeed = lib.mkOption {
              type = lib.types.float;
              default = 0.0;
              example = -0.3;
              description = ''
                libinput pointer acceleration, -1.0 to 1.0.

                0.0 is the device's own default, not "off". Negative is slower,
                positive faster; the pointer stays accelerated throughout. Turning
                acceleration off is a different setting (`accel_profile = flat`)
                and is not exposed here.
              '';
            };
          };
        };
      };
    });
  };
}
