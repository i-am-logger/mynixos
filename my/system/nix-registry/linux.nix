# nixpkgs for `nix shell nixpkgs#…`, `<nixpkgs>` and `nix-shell -p` is the one
# this system was built from.
#
# The registry and NIX_PATH halves need nothing here: lib.nixosSystem from the
# nixpkgs flake sets nixpkgs.flake.source, and nixos/modules/misc/nixpkgs-flake.nix
# then points nix.registry.nixpkgs at it and NIX_PATH at nixpkgs=flake:nixpkgs
# (tests/module-eval.nix nix-registry-pinned keeps that true).
#
# What is left is channels: an unpinned nixpkgs download that NIX_PATH also
# lists. The fleet is flakes only and has never subscribed one -- the entry
# names a directory that does not exist, and every evaluation warns about it.
# Off, NIX_PATH is exactly nixpkgs=flake:nixpkgs (owner, 2026-11-15).
{ lib, ... }:

{
  nix.channel.enable = lib.mkDefault false;
}
