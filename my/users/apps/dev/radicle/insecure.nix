# radicle-node is marked insecure in nixpkgs, citing Radicle's own disclosure
# (https://radicle.dev/2026/09/23/disclosure-of-vulnerability-in-network-protocol):
# traffic for private repositories between nodes is neither encrypted nor
# authenticated.
#
# Permitted on the owner's decision (2026-11-15), where radicle is in use and
# nowhere else: the fleet's radicle traffic stays on the tailnet, whose
# WireGuard tunnels encrypt it and authenticate each node -- the two things
# the protocol does not do itself. The version this names is the one the
# fleet already ran before nixpkgs marked it; a release that fixes the
# protocol has a new name, is not marked, and makes this inert.
#
# Both the per-user CLI (mkApp builds it from the system's pkgs) and the
# Linux services read the system nixpkgs, so this is set there. This file is
# the per-user half, loaded from platforms/common.nix; the forge's option is
# Linux-only, so its half is ./insecure-linux.nix.
{ config, lib, ... }:

let
  anyUser = lib.any
    (userCfg: userCfg.apps.dev.tools.radicle.enable)
    (lib.attrValues config.my.users);
in
{
  config = lib.mkIf anyUser {
    nixpkgs.config.permittedInsecurePackages = [ (import ./insecure-package.nix) ];
  };
}
