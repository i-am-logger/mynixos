# The per-user fleet-mail wake option -- declared here, not in ./options.nix,
# so it exists on Linux ALONE: ./linux.nix implements it as home-manager
# systemd user units, which nix-darwin does not provide. Merges with the
# claude-code app option declared in ./options.nix.
{ lib, ... }:

{
  options.my.users = lib.mkOption {
    type = lib.types.attrsOf (lib.types.submodule {
      options.apps.ai.tools.claude-code.fleetWake.enable = lib.mkEnableOption ''
        fleet-new.path and fleet-new.service: a change in ~/.claude/fleet/new/
        writes a line to ~/.claude/fleet/events.fifo, which wakes fleetd's
        watch.sh at once instead of on its 300 s round. User units, started at
        login (linger stays off). Takes effect with claude-code itself enabled'';
    });
  };
}
