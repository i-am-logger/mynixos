# Applies the fixes in this directory to both pkgs instances a system has.
#
# mkSystem does not set `home-manager.useGlobalPkgs`, so home-manager
# instantiates its own nixpkgs and a system-level `nixpkgs.overlays` does not
# reach it. Anything fixing a home-manager package (helix -> tree-sitter, at the
# time of writing) has to be re-propagated per user — the same shape
# my/system/unfree uses for allowUnfreePredicate.
#
# The test harnesses are the third case; they cannot be reached from a module at
# all and import the fix files directly (see tests/integration-smoke.nix).
{ activeUsers, config, lib, ... }:

let
  overlays = [
    (import ./tree-sitter.nix)
    (import ./cava.nix)
  ];
in
{
  config = {
    nixpkgs.overlays = overlays;

    home-manager.users = lib.mapAttrs
      (_name: _userCfg: { nixpkgs.overlays = overlays; })
      (activeUsers config.my.users);
  };
}
