{ pkgs, ... }:

# AMD iGPU GPU-fault forensics for this Raphael (gfx10.3.6 / RDNA2) host.
#
# Context: a web page (Brave's GPU process) can issue a shader that triggers a
# GCVM_L2_PROTECTION_FAULT -> `ring gfx_0.1.0` timeout -> full MODE2 GPU reset,
# which Hyprland does not survive (it RASSERT-aborts in CHyprOpenGLImpl::begin,
# hyprwm/Hyprland#9746). This module does NOT mitigate the crash and removes no
# feature; it makes the NEXT occurrence diagnosable to ROOT CAUSE by preserving
# the two highest-value artifacts, both of which were LOST in the 2026-06-14
# event:
#
#   1. the amdgpu *devcoredump* — the faulting shader / IB disassembly — which
#      the kernel auto-expires ~5 min after creation; copied here to
#      /var/log/gpu-forensics before it disappears; and
#   2. a *persistent* journal (kernel amdgpu fault block + Brave's GPU-process
#      log), so the evidence survives the reboot that usually follows the
#      session-killing reset.
#
# /var/log and /var/lib/systemd (systemd-coredump) are already in the
# impermanence persistence set (my/storage/impermanence/impermanence.nix), so
# both the captures and the process coredumps survive reboots with no extra
# persistence wiring.

let
  # Copy a devcoredump out before the kernel reclaims it, then release it.
  captureDevcoredump = pkgs.writeShellScript "amdgpu-devcoredump-capture" ''
    set -euo pipefail
    inst="''${1:?usage: amdgpu-devcoredump-capture <devcdN>}"
    src="/sys/class/devcoredump/''${inst}/data"
    outdir="/var/log/gpu-forensics"
    out="''${outdir}/amdgpu-devcoredump-$(${pkgs.coreutils}/bin/date +%Y%m%d-%H%M%S)-''${inst}.bin"
    ${pkgs.coreutils}/bin/mkdir -p "''${outdir}"
    if [ -r "''${src}" ]; then
      ${pkgs.coreutils}/bin/cp "''${src}" "''${out}"
      echo "amdgpu-devcoredump: captured ''${src} -> ''${out} ($(${pkgs.coreutils}/bin/stat -c %s "''${out}") bytes)"
      # We have a copy; free the kernel dump promptly (it would otherwise linger
      # ~5 min, pinning GPU-dump memory).
      echo 1 > "''${src}" || true
    else
      echo "amdgpu-devcoredump: ''${src} not readable; nothing captured" >&2
    fi
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

  systemd.tmpfiles.rules = [
    "d /var/log/gpu-forensics 0750 root root -"
  ];

  # Retain the journal (kernel amdgpu fault + Brave GPU-process log) across the
  # reboot that typically follows a session-killing GPU reset. /var/log is
  # already persisted, so this just forces journald to write there.
  services.journald.extraConfig = ''
    Storage=persistent
    SystemMaxUse=2G
  '';
}
