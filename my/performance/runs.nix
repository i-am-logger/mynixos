{ config, lib, ... }:

with lib;

let
  cfg = config.my.performance.runs;
in
{
  # releasable reads runs.slice's MemoryMax from the user manager (busctl
  # --user, unit runs_2eslice) and refuses every run while it is infinity;
  # each run then gets a child slice under it. This mirrors releasable's
  # nix/runs/nixos.nix, which mynixos cannot take as an input (it is fetched
  # as git+file or a Radicle RID). No MemoryHigh: with no swap it would hold a
  # runaway at the bound instead of the kernel ending it. No CPU property: CPU
  # on this fleet is shared out by affinity, not by slices.
  config = mkIf (cfg.budget != null) {
    systemd.user.slices.runs = {
      description = "Memory budget shared by every run";
      sliceConfig = {
        MemoryMax = cfg.budget;
        MemorySwapMax = 0;
      };
    };
  };
}
