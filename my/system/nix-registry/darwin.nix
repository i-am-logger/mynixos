# nixpkgs for `nix shell nixpkgs#…`, `<nixpkgs>` and `nix-shell -p` is the one
# this system was built from -- on a Mac whose Nix nix-darwin does not manage.
#
# nix-darwin's darwinSystem sets nixpkgs.flake.source, but writes the registry
# and NIX_PATH from it only when it manages Nix (nix.enable), and asserts as
# much. This fleet's Macs set nix.enable = false: the nix-installer owns Nix.
# So nothing was pinned, and `nixpkgs` meant whatever the global registry
# fetched that day. This writes the same two things directly, system-wide (root
# and sudo included), and stands aside when nix.enable is true, where
# nix-darwin's own defaults do it.
{ config, lib, ... }:

lib.mkIf (!config.nix.enable && config.nixpkgs.flake.source != null) {
  environment.etc."nix/registry.json".text = builtins.toJSON {
    version = 2;
    flakes = [{
      exact = true;
      from = { type = "indirect"; id = "nixpkgs"; };
      to = { type = "path"; path = toString config.nixpkgs.flake.source; };
    }];
  };
  environment.variables.NIX_PATH = "nixpkgs=flake:nixpkgs";
}
