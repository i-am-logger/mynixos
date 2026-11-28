{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.my.hardware.gpu;
  frl = config.my.hardware.display.hdmiFrl;
  f = config.my.forensics;

  # Rescue an amdgpu devcoredump (the faulting shader / IB disassembly) before
  # the kernel auto-expires it (~5 min), into the forensics tree wheel-readable.
  # Driven by my.forensics.gpu. An app with a GPU log of its own adds it to the
  # capture unit itself (Brave: my/users/apps/browsers/brave/linux.nix).
  captureDevcoredump = pkgs.writeShellScript "amdgpu-devcoredump-capture" ''
    set -euo pipefail
    inst="''${1:?usage: amdgpu-devcoredump-capture <devcdN>}"
    src="/sys/class/devcoredump/''${inst}/data"
    # The devcoredump udev rule fires for EVERY driver's dump; this capturer is
    # amdgpu-specific. Resolve the failing device's driver and skip known
    # non-amdgpu drivers (an undetermined driver is still captured - keep
    # evidence rather than miss the amdgpu dump).
    drv="$(${pkgs.coreutils}/bin/basename "$(${pkgs.coreutils}/bin/readlink -f "/sys/class/devcoredump/''${inst}/failing_device/driver" 2>/dev/null)" 2>/dev/null || echo unknown)"
    if [ "''${drv}" != "amdgpu" ] && [ "''${drv}" != "unknown" ]; then
      echo "amdgpu-devcoredump: ''${inst} is from driver ''${drv}, not amdgpu; skipping" >&2
      exit 0
    fi
    outdir="/var/log/forensics/gpu"
    out="''${outdir}/amdgpu-devcoredump-$(${pkgs.coreutils}/bin/date +%Y%m%d-%H%M%S)-''${inst}.bin"
    ${pkgs.coreutils}/bin/mkdir -p "''${outdir}"
    if [ -r "''${src}" ]; then
      ${pkgs.coreutils}/bin/cp "''${src}" "''${out}"
      # Forensics that need root to read are forensics no one reads; make the
      # capture group-readable by wheel so it can be analysed without sudo.
      ${pkgs.coreutils}/bin/chgrp wheel "''${out}" 2>/dev/null || true
      ${pkgs.coreutils}/bin/chmod 0640 "''${out}"
      echo "amdgpu-devcoredump: captured ''${src} -> ''${out} ($(${pkgs.coreutils}/bin/stat -c %s "''${out}") bytes)"
      # Free the kernel dump promptly (it would otherwise linger ~5 min, pinning
      # GPU-dump memory).
      echo 1 > "''${src}" || true
    else
      echo "amdgpu-devcoredump: ''${src} not readable; nothing captured" >&2
    fi
  '';
in
{
  imports = [ ./sensors.nix ];

  config = mkMerge [
    # Generic AMD Radeon GPU enablement - the amdgpu driver + Mesa/VA-API. This
    # module is shared by every AMD-GPU host, so it stays generic: machine- or
    # iGPU-specific kernel params and quirks (e.g. GFXOFF disable, deep colour
    # for a particular display) belong in the *machine* driver - see the
    # motherboard's drivers/amd-integrated-gpu.nix - not here.
    (mkIf (cfg == "amd") {
      boot = {
        initrd.kernelModules = [ "amdgpu" ];
        kernelModules = [ "amdgpu" ];
      };

      # Graphics hardware configuration
      hardware.graphics = {
        enable = true;
        # No enable32Bit: only Steam/Wine need the 32-bit stack (~0.9 GiB), and
        # nixpkgs' programs.steam turns it on itself.
        extraPackages = with pkgs; [
          libvdpau-va-gl
          libva-utils
        ];
      };
    })

    # GPU fault forensics for this driver (my.forensics.gpu): capture every
    # amdgpu devcoredump the instant the kernel creates one. The udev RUN+= only
    # kicks off a --no-block unit, so the udev event itself stays short.
    (mkIf (cfg == "amd" && f.enable && f.gpu.enable) {
      systemd.tmpfiles.rules = [ "d /var/log/forensics/gpu 2750 root wheel -" ];

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
    })

    # HDMI 2.1 FRL. amdgpu gained FRL in 7.2 behind DC_FRL_MASK (1 << 10) and
    # turns it on by default from 7.4, whose default dc_feature_mask is
    # MULTI_MON_PP_MCLK_SWITCH | FRL = 0x402. The parameter REPLACES the default
    # mask rather than adding to it, so it restates 7.4's whole default instead
    # of setting the FRL bit alone -- which would drop the MCLK-switch bit.
    (mkIf frl.enable {
      assertions = [{
        assertion = cfg == "amd";
        message = "my.hardware.display.hdmiFrl.enable is an amdgpu display-core switch, so it needs my.hardware.gpu = \"amd\" (it is ${if cfg == null then "null" else "\"${cfg}\""}).";
      }];
      boot.kernelParams = mkIf (cfg == "amd" && versionOlder config.boot.kernelPackages.kernel.version "7.4")
        [ "amdgpu.dc_feature_mask=0x402" ];
    })
  ];
}
