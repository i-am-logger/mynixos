{ activeUsers, config, lib, pkgs, ... }:

with lib;

let
  cfg = config.my.security;

  # Check if any user has yubikeys configured
  hasYubikey = any (user: (length user.yubikeys) > 0)
    (attrValues config.my.users);

  # Get all yubikey users
in
{
  config = mkMerge [
    # Secure Boot configuration
    (mkIf (cfg.enable && cfg.secureBoot.enable) {
      boot = {
        bootspec.enable = true;
        lanzaboote = {
          enable = true;
          pkiBundle = "/var/lib/sbctl";
          settings = {
            kernelSigningKeyPath = "/var/lib/sbctl/keys/db/db.key";
            kernelSigningCertPath = "/var/lib/sbctl/keys/db/db.pem";
            signByDefault = true;
          };
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

    # YubiKey configuration (enabled when security stack is enabled and any user has yubikey)
    (mkIf (cfg.enable && (cfg.yubikey.enable || hasYubikey)) {
      services = {
        pcscd = {
          enable = true;
          plugins = [ pkgs.ccid ];
        };

        yubikey-agent.enable = false; # Use gpg-agent instead

        udev.packages = [
          pkgs.yubikey-personalization
          pkgs.libu2f-host
        ];

        # Disable GNOME keyring entirely — using pass with GPG/YubiKey instead.
        # All three settings are required: NixOS service, PAM integration, and env vars.
        gnome = {
          gnome-keyring.enable = false;
          glib-networking.enable = true;
        };
      };

      systemd = {
        services.pcscd = {
          enable = true;
          wantedBy = [ "multi-user.target" ];
        };

        # YubiKey touch detector service
        user.services.yubikey-touch-detector = {
          enable = true;
          description = "Detects when YubiKey is waiting for a touch";
          wantedBy = [ "graphical-session.target" ];
          partOf = [ "graphical-session.target" ];
          after = [ "graphical-session.target" ];
          serviceConfig = {
            ExecStart = "${pkgs.yubikey-touch-detector}/bin/yubikey-touch-detector --libnotify";
            Restart = "always";
            RestartSec = 1;
            Environment = [ "PATH=${pkgs.libnotify}/bin" ];
          };
        };
      };

      hardware.gpgSmartcards.enable = true;

      environment = {
        systemPackages = with pkgs; [
          pinentry-gnome3
          gopass
          ripasso-cursive
          libsecret
          libnotify
          yubikey-touch-detector
          yubikey-manager
        ];

        # PAM U2F configuration for yubikey users
        # Generate u2f_keys file from user yubikey data
        # Format: username:keyHandle1,publicKey1,algorithm,flags:keyHandle2,publicKey2,algorithm,flags
        # U2F keys must be registered using: pamu2fcfg -u <username>
        # See: https://developers.yubico.com/pam-u2f/

        # Create u2f_keys file in nix store from user configurations
        etc."u2f_keys".text = lib.concatStringsSep "\n" (
          lib.filter (line: line != "") (
            lib.mapAttrsToList
              (username: userCfg:
                if (length userCfg.yubikeys) > 0
                then "${username}:${lib.concatMapStringsSep ":" (yk:
                  # Format: keyHandle,publicKey,algorithm,flags
                  "${yk.u2fKeyHandle},${yk.u2fPublicKey},${yk.u2fAlgorithm},${yk.u2fFlags}"
                ) userCfg.yubikeys}"
                else ""
              )
              (activeUsers config.my.users)
          )
        );

        sessionVariables = {
          GNOME_KEYRING_CONTROL = "";
          DISABLE_GNOME_KEYRING = "1";
        };
      };

      security = {
        polkit.enable = true;

        pam = {
          services = {
            login.u2fAuth = true;
            sudo.u2fAuth = true;
            gdm = {
              u2fAuth = true;
              enableGnomeKeyring = false;
            };
            login.enableGnomeKeyring = false;
          };
          u2f = {
            enable = true;
            control = "sufficient";
            settings = {
              # Point to nix-managed u2f keys file in /etc
              authfile = "/etc/u2f_keys";
              cue = true;
              interactive = true;
              origin = "pam://";
              appid = "pam://";
            };
          };
        };
      };

      # Configure GPG agent
      programs = {
        gnupg.agent = {
          enable = true;
          enableSSHSupport = true;
          pinentryPackage = pkgs.pinentry-gnome3;
        };

        ssh.startAgent = false;
        dconf.enable = true;
      };

      # Required groups and user group membership
      users = {
        groups.plugdev = { };
        groups.pcscd = { };

        # Add users to security-related groups
        users = mapAttrs
          (_name: _userCfg: {
            extraGroups = [ "plugdev" "pcscd" ];
          })
          (activeUsers config.my.users);
      };
    })

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

          # System configuration (NixOS specific)
          "-w /etc/nixos/ -p wa -k nixos_config"
          "-w /boot/ -p wa -k boot"

          # Login/logout events
          "-w /var/log/lastlog -p wa -k logins"

          # Session events
          "-w /var/run/utmp -p wa -k session"
          "-w /var/log/wtmp -p wa -k session"
          "-w /var/log/btmp -p wa -k session"
          # Note: -e 2 (immutable) is added automatically by NixOS when enable = "lock"
        ];

        sudo.extraConfig = ''
          Defaults timestamp_timeout=0
          Defaults !tty_tickets
          Defaults log_output
          Defaults log_input
          Defaults logfile=/var/log/sudo.log
        '';
      };

      # Disable filter plugin to avoid "line too long" error
      environment.etc."audit/plugins.d/filter.conf".text = mkDefault ''
        active = no
      '';
    })
  ];
}
