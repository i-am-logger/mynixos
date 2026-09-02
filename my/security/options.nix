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

        # sudo authenticated by a signature from the caller's forwarded SSH
        # agent, rather than by a security key plugged into THIS machine.
        #
        # This is what makes sudo usable on a headless host. pam_u2f asks for a
        # touch on the machine running sudo, which nobody is standing at; the
        # agent answers from wherever the operator actually is, with a key that
        # never crosses the network. The client half is
        # my.users.<name>.apps.terminal.network.ssh.forwardAgentHosts.
        #
        # The trusted keys are the authorized_keys files, NOT the user's own
        # ~/.ssh/authorized_keys: a file the user can write is a file the user
        # can add a key to, which would make this trivially self-granting.
        sshAgentSudo = lib.mkEnableOption "sudo authenticated by the caller's forwarded SSH agent";

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
