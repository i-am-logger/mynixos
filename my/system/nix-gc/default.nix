# Automatic Nix garbage collection on darwin, independent of nix-darwin.
#
# WHY NOT `nix.gc.automatic`
#
# nix-darwin asserts:
#
#   - nix.gc.automatic requires nix.enable
#   - nix.optimise.automatic requires nix.enable
#
# On hosts where Nix is owned by the NixOS nix-installer rather than nix-darwin
# (see the nix.enable comment in the host config for why that is the right call
# there), those options are unavailable — but the store still grows without
# bound. This provides the same behaviour with plain launchd daemons, which have
# no such gating.
#
# Drop this module and switch to `nix.gc` / `nix.optimise` if a host ever sets
# `nix.enable = true`.
{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.my.nixGc;
in
{
  config = mkIf cfg.enable {
    # Runs as root: the store is root-owned, and GC needs to reach every
    # profile's roots, not just the calling user's.
    launchd.daemons.mynixos-nix-gc = {
      serviceConfig = {
        Label = "org.mynixos.nix-gc";
        StartCalendarInterval = [ cfg.interval ];
        RunAtLoad = false;
        StandardErrorPath = "/var/log/mynixos-nix-gc.log";
      };
      command = "${pkgs.writeShellScript "mynixos-nix-gc" ''
        set -eu
        exec /nix/var/nix/profiles/default/bin/nix-collect-garbage --delete-older-than ${cfg.olderThan}
      ''}";
    };

    launchd.daemons.mynixos-nix-optimise = mkIf cfg.optimise {
      serviceConfig = {
        Label = "org.mynixos.nix-optimise";
        StartCalendarInterval = [ cfg.optimiseInterval ];
        RunAtLoad = false;
        StandardErrorPath = "/var/log/mynixos-nix-optimise.log";
      };
      command = "${pkgs.writeShellScript "mynixos-nix-optimise" ''
        set -eu
        exec /nix/var/nix/profiles/default/bin/nix --extra-experimental-features nix-command store optimise
      ''}";
    };
  };
}
