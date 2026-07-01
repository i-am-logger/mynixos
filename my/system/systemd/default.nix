{ config, lib, pkgs, ... }:

with lib;

let
  sys = config.my.system;
  f = config.my.forensics;
in
{
  # Systemd subsystem owner. Reads the cross-cutting my.forensics intent and
  # configures the systemd-side diagnostics - journald retention, userspace
  # coredumps, and kernel pstore persistence. Driver-specific captures (GPU
  # devcoredumps) live with their driver; the kernel boot params live in
  # my/system/core. This module owns only the systemd half.
  config = mkIf (sys.enable && sys.systemd.enable) (mkMerge [

    # Foundation: retain the system log across reboot, at the forensics level,
    # and provide the wheel-readable capture root.
    (mkIf f.enable {
      services.journald.extraConfig = ''
        Storage=persistent
        SystemMaxUse=2G
        MaxLevelStore=${f.level}
      '';
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

    # Kernel: copy the surviving pstore panic/oops record into the forensics
    # tree, wheel-readable, on boot. The boot-param half (reserve_mem + the
    # ramoops module) lives in my/system/core.
    (mkIf (f.enable && f.kernel.enable) {
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
  ]);
}
