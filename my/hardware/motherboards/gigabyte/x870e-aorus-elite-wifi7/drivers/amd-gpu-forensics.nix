{ pkgs, ... }:

# AMD iGPU GPU-fault forensics for this Raphael (gfx10.3.6 / RDNA2) host.
#
# A GPU shader reading an unmapped or permission-revoked address raises a
# GCVM_L2_PROTECTION_FAULT that can escalate to a ring timeout and a full GPU
# reset, which a Wayland compositor does not survive. This module does not
# mitigate the fault and removes no feature; it makes the fault diagnosable to
# root cause by preserving, at the moment of a reset, the three highest-value
# artifacts:
#
#   1. the amdgpu devcoredump — the faulting shader / IB disassembly — which
#      the kernel auto-expires ~5 min after creation; copied to
#      /var/log/gpu-forensics before it disappears;
#   2. a snapshot of each browser's GPU debug log, taken before the browser
#      relaunches and truncates it (the log names the page and shader); and
#   3. a persistent journal carrying the kernel amdgpu fault block.
#
# /var/log is in the impermanence persistence set
# (my/storage/impermanence/impermanence.nix), so the captures survive reboots
# with no extra persistence wiring.

let
  # Copy a devcoredump out before the kernel reclaims it, then release it.
  captureDevcoredump = pkgs.writeShellScript "amdgpu-devcoredump-capture" ''
    set -euo pipefail
    inst="''${1:?usage: amdgpu-devcoredump-capture <devcdN>}"
    src="/sys/class/devcoredump/''${inst}/data"
    # The devcoredump udev rule fires for EVERY driver's dump, but this unit is
    # amdgpu-specific. Resolve the failing device's driver and skip anything that
    # is a known non-amdgpu driver. An undetermined driver is still captured —
    # better to keep evidence than miss the amdgpu dump we are here for.
    drv="$(${pkgs.coreutils}/bin/basename "$(${pkgs.coreutils}/bin/readlink -f "/sys/class/devcoredump/''${inst}/failing_device/driver" 2>/dev/null)" 2>/dev/null || echo unknown)"
    if [ "''${drv}" != "amdgpu" ] && [ "''${drv}" != "unknown" ]; then
      echo "amdgpu-devcoredump: ''${inst} is from driver ''${drv}, not amdgpu; skipping" >&2
      exit 0
    fi
    outdir="/var/log/gpu-forensics"
    out="''${outdir}/amdgpu-devcoredump-$(${pkgs.coreutils}/bin/date +%Y%m%d-%H%M%S)-''${inst}.bin"
    ${pkgs.coreutils}/bin/mkdir -p "''${outdir}"
    if [ -r "''${src}" ]; then
      ${pkgs.coreutils}/bin/cp "''${src}" "''${out}"
      # Forensics that need root to read are forensics no one reads. Make the
      # capture group-readable by wheel so it can be analysed without sudo.
      ${pkgs.coreutils}/bin/chgrp wheel "''${out}" 2>/dev/null || true
      ${pkgs.coreutils}/bin/chmod 0640 "''${out}"
      echo "amdgpu-devcoredump: captured ''${src} -> ''${out} ($(${pkgs.coreutils}/bin/stat -c %s "''${out}") bytes)"
      # We have a copy; free the kernel dump promptly (it would otherwise linger
      # ~5 min, pinning GPU-dump memory).
      echo 1 > "''${src}" || true
    else
      echo "amdgpu-devcoredump: ''${src} not readable; nothing captured" >&2
    fi

    # Snapshot each browser's GPU debug log alongside the dump, before the
    # browser relaunches and truncates it. This ties the reset to the page and
    # shader that triggered it.
    for blog in /home/*/.cache/brave-gpu-debug.log; do
      [ -r "''${blog}" ] || continue
      u="''${blog#/home/}"; u="''${u%%/*}"
      snap="''${outdir}/brave-gpu-''${u}-$(${pkgs.coreutils}/bin/date +%Y%m%d-%H%M%S)-''${inst}.log"
      if ${pkgs.coreutils}/bin/cp "''${blog}" "''${snap}" 2>/dev/null; then
        ${pkgs.coreutils}/bin/chgrp wheel "''${snap}" 2>/dev/null || true
        ${pkgs.coreutils}/bin/chmod 0640 "''${snap}"
        echo "amdgpu-devcoredump: snapshotted browser log ''${blog}"
      fi
    done
  '';
in
{
  # Capture every device coredump the instant the kernel creates one. amdgpu
  # raises one on each GPU recovery; the RUN+= only kicks off a --no-block unit,
  # so the udev event itself stays short.
  services.udev.extraRules = ''
    SUBSYSTEM=="devcoredump", ACTION=="add", RUN+="${pkgs.systemd}/bin/systemctl --no-block start amdgpu-devcoredump-capture@%k.service"
  '';

  systemd.services."amdgpu-devcoredump-capture@" = {
    description = "Capture amdgpu devcoredump %i before kernel auto-expiry";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${captureDevcoredump} %i";
    };
  };

  # setgid + wheel group so captures land group-readable and stay analysable
  # without sudo (see the chgrp/chmod in the capture script).
  systemd.tmpfiles.rules = [
    "d /var/log/gpu-forensics 2750 root wheel -"
  ];

  # Retain the kernel amdgpu fault block across reboots. /var/log is already
  # persisted, so this just forces journald to write there.
  services.journald.extraConfig = ''
    Storage=persistent
    SystemMaxUse=2G
  '';
}
