# Brave on Linux: its persistence, and its half of the amdgpu fault capture.
#
# `my.system.persistence.features` is impermanence's collection point and the
# capture unit is systemd's, both declared only on Linux, so the writes live
# here rather than in ./default.nix, which platforms/common.nix imports for both
# platforms. macOS has no impermanence and no devcoredump.
#
# Persistence is fleet-wide rather than per-user, because the app is chosen
# through a selector (environment.BROWSER) and so has no apps.* option to carry
# persistedDirectories. Brave's profile -- logins, cookies, extensions, history.
#
# Imported only by platforms/linux.nix.
{ activeUsers, config, lib, pkgs, ... }:

with lib;

let
  isBrave = userCfg: let b = userCfg.environment.BROWSER; in b != null && b.enable && (b.package.pname or "") == "brave";
  braveUsers = attrNames (filterAttrs (_: isBrave) (activeUsers config.my.users));
  f = config.my.forensics;

  # The wrapper in ./default.nix keeps Brave's GPU-process log in
  # ~/.cache/brave-gpu-debug.log, and Brave truncates it when it relaunches
  # after a GPU reset. Copied into the forensics tree with the devcoredump, it
  # ties the reset to the page and shader that triggered it. Runs before the
  # capture (ExecStartPre, failure ignored), while the devcoredump still names
  # its driver, so a dump from another driver snapshots nothing -- as the
  # capture itself skips it.
  snapshot = pkgs.writeShellScript "brave-gpu-log-snapshot" ''
    set -uo pipefail
    inst="''${1:?usage: brave-gpu-log-snapshot <devcdN>}"
    drv="$(${pkgs.coreutils}/bin/basename "$(${pkgs.coreutils}/bin/readlink -f "/sys/class/devcoredump/''${inst}/failing_device/driver" 2>/dev/null)" 2>/dev/null || echo unknown)"
    if [ "''${drv}" != "amdgpu" ] && [ "''${drv}" != "unknown" ]; then
      exit 0
    fi
    outdir="/var/log/forensics/gpu"
    ${pkgs.coreutils}/bin/mkdir -p "''${outdir}"
    for u in ${escapeShellArgs braveUsers}; do
      blog="/home/''${u}/.cache/brave-gpu-debug.log"
      [ -r "''${blog}" ] || continue
      snap="''${outdir}/brave-gpu-''${u}-$(${pkgs.coreutils}/bin/date +%Y%m%d-%H%M%S)-''${inst}.log"
      if ${pkgs.coreutils}/bin/cp "''${blog}" "''${snap}" 2>/dev/null; then
        ${pkgs.coreutils}/bin/chgrp wheel "''${snap}" 2>/dev/null || true
        ${pkgs.coreutils}/bin/chmod 0640 "''${snap}"
        echo "brave-gpu-log-snapshot: snapshotted ''${blog}"
      fi
    done
  '';
in
{
  config = mkMerge [
    {
      my.system.persistence.features.userDirectories =
        optionals (braveUsers != [ ]) [ ".config/BraveSoftware" ];
    }

    # Added to my/hardware/gpu/amd's capture unit, which exists exactly when
    # this condition holds.
    (mkIf (braveUsers != [ ] && config.my.hardware.gpu == "amd" && f.enable && f.gpu.enable) {
      systemd.services."amdgpu-devcoredump-capture@".serviceConfig.ExecStartPre = [ "-${snapshot} %i" ];
    })
  ];
}
