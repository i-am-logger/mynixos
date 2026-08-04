# Per-user pointer and input preferences.
#
# These belong to the PERSON, not the machine and not the window manager. Two
# users on one host can differ, which is why they live under `my.users.<n>` and
# not under `my.hardware` (that describes what the machine is, and is singular
# per host).
#
# Only concepts that mean the SAME thing on every platform are declared here.
# Anything whose scale or semantics differ is declared on the platform that
# implements it — see ./options-linux.nix for accelSpeed, which has no faithful
# macOS equivalent.
#
# Consumers: Hyprland (my/graphical/hyprland) on Linux, and
# my/users/input/darwin.nix on macOS.

{ lib, ... }:

{
  options.input = lib.mkOption {
    description = "Pointer and input preferences for this user";
    default = { };
    type = lib.types.submodule {
      options = {
        leftHanded = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = ''
            Swap the primary and secondary pointer buttons.

            Device-global on Linux: Hyprland's `input:left_handed` applies to
            every pointer including a laptop touchpad, so this is not scoped to
            a mouse. macOS applies it to the mouse only, having no trackpad
            handedness setting at all.
          '';
        };

        naturalScroll = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = ''
            Content follows finger direction rather than the scrollbar.

            One switch for every pointing device. Hyprland has separate mouse and
            touchpad keys and macOS has a single global one, so per-device scroll
            direction is deliberately not expressible — neither host sets them
            differently, and splitting them would model a distinction the user
            does not make.
          '';
        };
      };
    };
  };
}
