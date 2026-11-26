# devenv's binary cache, for the hosts where someone uses devenv.
#
# devenv's own build (and the devenv-nixpkgs its environments evaluate) is
# served from devenv.cachix.org; without it the first `devenv shell` compiles.
# The `extra-` keys add to nix's lists rather than replacing them, so
# cache.nixos.org stays first. Linux only: on darwin Nix belongs to the
# nix-installer (nix.enable = false), not to nix-darwin.
#
# Imported only by platforms/linux.nix; the app itself is ./default.nix.
{ config, lib, ... }:

let
  anyUser = lib.any
    (userCfg: userCfg.apps.dev.tools.devenv.enable)
    (lib.attrValues config.my.users);
in
{
  config = lib.mkIf anyUser {
    nix.settings = {
      extra-substituters = [ "https://devenv.cachix.org" ];
      extra-trusted-public-keys = [ "devenv.cachix.org-1:w1cLUi8dv3hnoSPGAuibQv+f9TZLr6cv/Hm9XgU50cw=" ];
    };
  };
}
