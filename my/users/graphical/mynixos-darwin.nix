# mynixos Opinionated Defaults: Graphical, darwin
#
# macOS cannot not be graphical: there is no headless variant, and Aqua is part
# of the OS rather than something a configuration installs. So `graphical.enable`
# is forced rather than defaulted -- a darwin host setting it to false would be
# asserting something untrue about the machine. (The knob for "fewer GUI apps" is
# the individual `apps.graphical.*.enable` options, not this flag.)
#
# This file is imported only by platforms/darwin.nix, so it needs no
# `pkgs.stdenv.hostPlatform.isDarwin` test -- it cannot run anywhere else.
#
# What this does NOT do is drag in Hyprland. `graphical.enable` keeps one meaning
# -- "this user has a GUI" -- and the platform decides what follows: the
# Wayland/X11 app defaults live in ./mynixos-linux.nix, so they are never set
# here, and the modules implementing them are absent from platforms/darwin.nix.

{ lib, ... }:

{
  options.my.users = lib.mkOption {
    type = lib.types.attrsOf (lib.types.submodule {
      config.graphical.enable = lib.mkForce true;
    });
  };
}
