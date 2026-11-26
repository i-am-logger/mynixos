# Crash and fault diagnostics (my.forensics), the kernel and userspace halves.
#
# The domain owns what it captures: the ramoops reservation that keeps a panic
# across the reboot, the journal kept on disk at the forensics level, systemd's
# coredumps, and the copy of each pstore record into /var/log/forensics. None
# of it depends on my.system: a host that turns forensics on gets forensics.
#
# The GPU half stays a driver hook (my/hardware/gpu/amd), because a
# devcoredump is the driver's own format.
{ config, lib, pkgs, ... }:

with lib;

let
  f = config.my.forensics;
in
{
  config = mkMerge [
    # Foundation: retain the system log across reboot, at the forensics level,
    # and provide the wheel-readable capture root.
    (mkIf f.enable {
      services.journald.settings.Journal = {
        Storage = "persistent";
        SystemMaxUse = "2G";
        MaxLevelStore = f.level;
      };
      systemd.tmpfiles.rules = [ "d /var/log/forensics 2750 root wheel -" ];
    })

    # Userspace: retain process coredumps so a crash is inspectable with
    # coredumpctl. /var/lib/systemd is in the impermanence persist set.
    (mkIf (f.enable && f.userspace.enable) {
      systemd.coredump.enable = true;
      systemd.coredump.settings.Coredump = {
        Storage = "external";
        Compress = true;
        ProcessSizeMax = "2G";
        ExternalSizeMax = "2G";
        MaxUse = "4G";
      };
    })

    # Kernel: pstore-ramoops records a panic/oops across the reboot, and the
    # surviving record is copied into the forensics tree, wheel-readable.
    # A container has no kernel of its own to capture.
    (mkIf (f.enable && f.kernel.enable && !config.boot.isContainer) {
      boot = {
        # Loaded early so it is armed before anything can splat.
        initrd.kernelModules = [ "ramoops" ];
        kernelModules = [ "ramoops" ];
        kernelParams = [
          "reserve_mem=4M:4096:oops"
          "ramoops.mem_name=oops"
          # Without explicit record/console sizes, ramoops_probe() rejects a
          # non-zero region and pstore never appears - nothing would be
          # captured. 128 KiB each holds a full panic/oops dmesg + console.
          "ramoops.record_size=0x20000"
          "ramoops.console_size=0x20000"
          "ramoops.ecc=1"
        ];
      };

      systemd.tmpfiles.rules = [ "d /var/log/forensics/kernel 2750 root wheel -" ];
      systemd.services.forensics-pstore-persist = {
        description = "Persist kernel pstore records (panics/oopses) to /var/log/forensics/kernel";
        wantedBy = [ "multi-user.target" ];
        after = [ "systemd-pstore.service" ];
        serviceConfig.Type = "oneshot";
        script = ''
          set -euo pipefail
          out=/var/log/forensics/kernel
          ${pkgs.coreutils}/bin/mkdir -p "$out"
          shopt -s nullglob
          # systemd-pstore archives /sys/fs/pstore -> /var/lib/systemd/pstore
          # (persisted, Unlink=yes) under stable, unique names. Copy each record
          # once, keyed by that name, so reboots never re-duplicate. Do not touch
          # the sources - systemd-pstore owns /var/lib/systemd/pstore.
          for rec in /var/lib/systemd/pstore/* /sys/fs/pstore/*; do
            [ -f "$rec" ] || continue
            dst="$out/$(${pkgs.coreutils}/bin/basename "$rec")"
            [ -e "$dst" ] && continue
            ${pkgs.coreutils}/bin/cp "$rec" "$dst" 2>/dev/null || continue
            ${pkgs.coreutils}/bin/chgrp wheel "$dst" 2>/dev/null || true
            ${pkgs.coreutils}/bin/chmod 0640 "$dst"
          done
        '';
      };
    })
  ];
}
