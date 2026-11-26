{ config, lib, pkgs, ... }:

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

    # MemoryMax is the slice's one bound (teamlead, 2026-11-25): systemd-oomd
    # must not kill a gate inside it under pressure first. mynixos's oomd
    # setting reaches every user slice as the type-level drop-in
    # slice.d/overrides.conf, which outranks the unit file, so the exemption
    # is a drop-in too. Drop-ins apply in lexicographic order of filename
    # across directories, so it is named to sort after overrides.conf.
    # systemd.packages also feeds the user unit tree (its lib/systemd/user).
    systemd.packages = [
      (pkgs.writeTextDir "lib/systemd/user/runs.slice.d/zz-oomd-exempt.conf" ''
        [Slice]
        ManagedOOMMemoryPressure=auto
      '')
    ];
  };
}
