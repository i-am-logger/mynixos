{ lib, ... }:

{
  security = lib.mkOption {
    description = "Security stack configuration";
    default = { };
    type = lib.types.submodule {
      options = {
        enable = lib.mkEnableOption "security stack";

        secureBoot = {
          enable = lib.mkEnableOption "secure boot with lanzaboote";
        };

        # TPM2 measured-boot setup (systemd-tpm2-setup: the SRK + systemd 259's
        # NvPCR anchors). OFF by default: when the TPM isn't used (no TPM-backed
        # FDE), the setup is disabled and the per-generation NvPCR anchor creds it
        # writes to the ESP — which PID1 reports as "untrusted credentials" every
        # boot — are cleaned up. Turn ON when adopting TPM-sealed disk unlock.
        tpm = {
          enable = lib.mkEnableOption "TPM2 measured-boot setup (SRK + NvPCR anchors)";
        };

        auditRules = {
          enable = lib.mkEnableOption "audit rules";
        };

        nopasswdRebuild = lib.mkEnableOption "NOPASSWD sudo for nixos-rebuild (skips YubiKey touch on rebuild)";

        # Authentication DEVICES are not declared here — they live under
        # my.hardware (securityKeys.yubico, biometrics). This domain owns policy
        # and only observes them, warning when the security stack is on but no
        # auth hardware is configured. Password-only auth is legitimate, so this
        # is the opt-out for that warning.
        passwordAuthOnly = lib.mkEnableOption "password-only authentication on this host (silences the no-auth-hardware warning)";
      };
    };
  };
}
