{ activeUsers, config, lib, pkgs, ... }:

with lib;

let
  cfg = config.my.security;

  # Check if any user has yubikeys configured
  hasYubikey = any (user: (length user.yubikeys) > 0)
    (attrValues config.my.users);

  # Authentication DEVICES live under my.hardware; this domain owns policy, so
  # here we only observe them.
  #
  # Only the Linux-side device is consulted, because my/security is itself
  # Linux-only: my.hardware.biometrics is declared in platforms/darwin.nix and
  # does not exist here, so reading it would be an evaluation error, not `false`.
  authHardware = config.my.hardware.securityKeys.yubico.enable || hasYubikey;
in
{
  config = mkMerge [
    # Authentication devices are declared under my.hardware, so they are not
    # discoverable from `my.security.*`. A host can therefore enable the security
    # stack and end up with no authentication hardware without noticing.
    #
    # Report, do not enforce: password-only auth is a legitimate choice, which is
    # why this is a warning with an explicit opt-out rather than an assertion.
    (mkIf (cfg.enable && !authHardware && !cfg.passwordAuthOnly) {
      warnings = [
        ''
          my.security.enable = true, but no authentication hardware is configured.

          Authentication devices are declared under my.hardware:
            my.hardware.securityKeys.yubico.enable  - YubiKey (pcscd, udev, PAM, gnupg)
            my.hardware.biometrics.enable           - Touch ID / Watch ID (darwin only)

          If this host authenticates with passwords only, set
          my.security.passwordAuthOnly = true to silence this.
        ''
      ];
    })

    # Secure Boot configuration
    (mkIf (cfg.enable && cfg.secureBoot.enable) {
      boot = {
        # bootspec is always generated in current nixpkgs (the enable option was
        # removed); lanzaboote consumes it automatically.
        lanzaboote = {
          enable = true;
          pkiBundle = "/var/lib/sbctl";
          # Bound the boot menu: keep only the latest generations' UKIs.
          configurationLimit = mkDefault 10;
        };
      };

      environment = {
        # Add persistence for secure boot keys (if impermanence is enabled)
        persistence = mkIf config.my.storage.impermanence.enable {
          ${config.my.storage.impermanence.persistPath}.directories = [ "/var/lib/sbctl" ];
        };

        # Add sbctl for debugging and troubleshooting Secure Boot
        systemPackages = with pkgs; [ sbctl ];
      };
    })

    # TPM2 measured boot: when the TPM isn't used (tpm.enable = false, the
    # default), disable systemd's NvPCR/SRK setup so it stops writing a new
    # nvpcr-anchor credential to the ESP every generation, and remove the stale
    # ones. Otherwise they accumulate (one per generation) and PID1's
    # import-creds logs them as "untrusted credentials" on every boot — they are
    # measured into PCR 12 but never required, so it's pure noise without FDE.
    # Flip tpm.enable = true when adopting TPM-sealed disk unlock (it needs the SRK).
    (mkIf (cfg.enable && !cfg.tpm.enable) {
      systemd.services = {
        systemd-tpm2-setup.enable = false;
        systemd-tpm2-setup-early.enable = false;
      };

      # Remove ONLY the NvPCR anchor credentials (never pcrlock or other creds),
      # at boot. The stub still packs whatever is present this boot, so the line
      # clears from the next boot onward (once the ESP dir is empty). Path follows
      # the configured ESP mountpoint (efiSysMountPoint, mkDefault "/boot") so it
      # still tracks the real credentials dir on hosts that relocate the ESP.
      systemd.tmpfiles.rules = [
        "r! ${config.boot.loader.efi.efiSysMountPoint}/loader/credentials/nvpcr-anchor.*.cred"
      ];
    })

    # NOPASSWD sudo for nixos-rebuild (avoids YubiKey touch on every rebuild)
    (mkIf (cfg.enable && cfg.nopasswdRebuild) {
      security.sudo.extraRules = map
        (username: {
          users = [ username ];
          commands = [
            { command = "/run/current-system/sw/bin/nixos-rebuild"; options = [ "NOPASSWD" ]; }
          ];
        })
        (attrNames (activeUsers config.my.users));
    })

    # sudo answered by the caller's forwarded SSH agent.
    #
    # pam_ssh_agent_auth sits BEFORE pam_u2f in the NixOS auth stack and is also
    # `sufficient`, so the two compose without further ordering: over SSH the
    # signature short-circuits the stack, and a local console with no forwarded
    # agent falls through to the security-key touch exactly as before.
    #
    # NixOS adds `Defaults env_keep+=SSH_AUTH_SOCK` on its own here; without it
    # sudo would scrub the very socket the module has to reach.
    # sudo trusts EVERY one of the person's keys, the owner's decision
    # (2026-11-15: "keep full trust", "for all yubikeys"), resident ones
    # included. The cost is stated, not hidden: a key plugged into this machine
    # signs without a touch through the local gpg-agent, which every session
    # reaches (the yubico module falls SSH_AUTH_SOCK back to it when nothing was
    # forwarded), so on a host whose own key is trusted here sudo is
    # passwordless for every process running as the user. sudo still gets its
    # own root-owned file rather than the user's writable authorized_keys, so
    # the user cannot add a key to it.
    (mkIf (cfg.enable && cfg.sshAgentSudo.enable) (
      let
        sudoKeys = userCfg: filter (yk: yk.sshPublicKey != "") userCfg.yubikeys;

        usersWithKeys = filterAttrs
          (_: userCfg: sudoKeys userCfg != [ ])
          (activeUsers config.my.users);
      in
      {
        assertions = [
          {
            assertion = usersWithKeys != { };
            message = ''
              my.security.sshAgentSudo is enabled, but no user has a security key
              with an SSH public key, so sudo would trust an empty set and fall
              back to the security key prompt this option exists to replace.
            '';
          }
        ];

        environment.etc = mapAttrs'
          (name: userCfg: nameValuePair "sudo-ssh-agent-keys.d/${name}" {
            # A mode makes NixOS write a real root-owned file rather than a
            # symlink; pam_ssh_agent_auth walks the path and rejects anything
            # the user could rewrite.
            mode = "0444";
            text = concatMapStringsSep "\n" (yk: yk.sshPublicKey) (sudoKeys userCfg) + "\n";
          })
          usersWithKeys;

        security.pam = {
          sshAgentAuth = {
            enable = true;
            authorizedKeysFiles = [ "/etc/sudo-ssh-agent-keys.d/%u" ];
          };
          services.sudo.sshAgentAuth = true;
        };
      }
    ))

    # Audit rules configuration
    (mkIf (cfg.enable && cfg.auditRules.enable) {
      # Enable kernel-level audit system
      boot.kernelParams = [
        "audit_backlog_limit=2048"
        "audit=1"
      ];

      security = {
        auditd.enable = true;
        audit.enable = "lock";
        audit.rules = [
          # Root executions (all architectures)
          "-a exit,always -F arch=b64 -F euid=0 -S execve -k root_commands"
          "-a exit,always -F arch=b32 -F euid=0 -S execve -k root_commands"

          # All user executions (comprehensive process monitoring)
          "-a exit,always -F arch=b64 -S execve -k user_commands"
          "-a exit,always -F arch=b32 -S execve -k user_commands"

          # File modifications and deletions
          "-a exit,always -F arch=b64 -S unlink,unlinkat,rename,renameat,rmdir,truncate,ftruncate -k file_deletion"
          "-a exit,always -F arch=b32 -S unlink,unlinkat,rename,renameat,rmdir,truncate,ftruncate -k file_deletion"

          # Permission changes
          "-a exit,always -F arch=b64 -S chmod,fchmod,fchmodat,chown,fchown,fchownat,setxattr,lsetxattr,fsetxattr -k perm_mod"
          "-a exit,always -F arch=b32 -S chmod,fchmod,fchmodat,chown,fchown,fchownat,setxattr,lsetxattr,fsetxattr -k perm_mod"

          # Module loading
          "-a exit,always -F arch=b64 -S init_module,finit_module,delete_module -k modules"
          "-a exit,always -F arch=b32 -S init_module,finit_module,delete_module -k modules"

          # System time changes
          "-a exit,always -F arch=b64 -S adjtimex,settimeofday,clock_settime -k time_change"
          "-a exit,always -F arch=b32 -S adjtimex,settimeofday,clock_settime -k time_change"

          # Mount operations
          "-a exit,always -F arch=b64 -S mount,umount2 -k mount"
          "-a exit,always -F arch=b32 -S mount,umount2 -k mount"

          # User/group changes
          "-w /etc/passwd -p wa -k identity"
          "-w /etc/group -p wa -k identity"
          "-w /etc/shadow -p wa -k identity"

          # Sudoers file changes
          "-w /etc/sudoers -p wa -k sudoers"
          "-w /etc/sudoers.d/ -p wa -k sudoers"

          # System configuration (NixOS specific): the /etc/nixos watch is
          # appended below, only where /etc/nixos is a directory of its own.
          "-w /boot/ -p wa -k boot"

          # Login/logout events
          "-w /var/log/lastlog -p wa -k logins"

          # Session events
          "-w /var/run/utmp -p wa -k session"
          "-w /var/log/wtmp -p wa -k session"
          "-w /var/log/btmp -p wa -k session"
          # Note: -e 2 (immutable) is added automatically by NixOS when enable = "lock"
        ]
        # With my.system.etcNixos.link, /etc/nixos is a link to a checkout the
        # user owns and edits by design, so a write watch there is either the
        # link itself (a dir watch does not follow it) or every git and editor
        # write; the checkout's git history is the audit trail instead.
        ++ optional (config.my.system.etcNixos.link == null) "-w /etc/nixos/ -p wa -k nixos_config";

        sudo.extraConfig = ''
          Defaults timestamp_timeout=0
          Defaults !tty_tickets
          Defaults log_output
          Defaults log_input
          Defaults logfile=/var/log/sudo.log
        '';
      };

      # Disable audit-rules services since immutable mode (-e 2 via enable = "lock")
      # prevents reloading rules during nixos-rebuild switch
      systemd.services.audit-rules.enable = false;
      systemd.services.audit-rules-nixos.enable = false;

      # Disable filter plugin to avoid "line too long" error
      environment.etc."audit/plugins.d/filter.conf".text = mkDefault ''
        active = no
      '';
    })
  ];
}
