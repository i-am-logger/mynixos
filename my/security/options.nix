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

        yubikey = {
          enable = lib.mkEnableOption "yubikey support";
        };

        auditRules = {
          enable = lib.mkEnableOption "audit rules";
        };

        nopasswdRebuild = lib.mkEnableOption "NOPASSWD sudo for nixos-rebuild (skips YubiKey touch on rebuild)";
      };
    };
  };
}
