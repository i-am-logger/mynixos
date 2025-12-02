{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.my.features.security;

  # Check if any user has yubikeys configured
  hasYubikey = any (user: (length user.yubikeys) > 0)
    (attrValues config.my.users);

  # Get all yubikey users
  yubikeyUsers = filter (user: (length user.yubikeys) > 0)
    (attrValues config.my.users);
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

      # Add persistence for secure boot keys (if impermanence is enabled)
      environment.persistence = mkIf config.my.storage.impermanence.enable {
        ${config.my.storage.impermanence.persistPath}.directories = [ "/var/lib/sbctl" ];
      };

      # Add sbctl for debugging and troubleshooting Secure Boot
      environment.systemPackages = with pkgs; [ sbctl ];
    })

    # YubiKey configuration (enabled when security stack is enabled and any user has yubikey)
    (mkIf (cfg.enable && (cfg.yubikey.enable || hasYubikey)) {
      services.pcscd = {
        enable = true;
        plugins = [ pkgs.ccid ];
      };

      systemd.services.pcscd = {
        enable = true;
        wantedBy = [ "multi-user.target" ];
      };

      services.yubikey-agent.enable = false; # Use gpg-agent instead
      hardware.gpgSmartcards.enable = true;

      services.udev.packages = [
        pkgs.yubikey-personalization
        pkgs.libu2f-host
      ];

      environment.systemPackages = with pkgs; [
        pinentry-gnome3
        gopass
        ripasso-cursive
        libsecret
        libnotify
        yubikey-touch-detector
        yubikey-manager
      ];

      # Disable GNOME keyring - using pass with GPG/YubiKey
      services.gnome.gnome-keyring.enable = false;
      security.polkit.enable = true;

      # Configure GPG agent
      programs.gnupg.agent = {
        enable = true;
        enableSSHSupport = true;
        pinentryPackage = pkgs.pinentry-gnome3;
      };

      # PAM U2F configuration for yubikey users
      security.pam = {
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
            cue = true;
            interactive = true;
            max_devices = 2;
            origin = "pam://";
            appid = "pam://";
            authpending_file = "/var/run/user/%i/pam-u2f-authpending";
          };
        };
      };

      # Required groups
      users.groups.plugdev = { };
      users.groups.pcscd = { };

      environment.sessionVariables = {
        GNOME_KEYRING_CONTROL = "";
        DISABLE_GNOME_KEYRING = "1";
      };

      programs.ssh.startAgent = false;
      programs.dconf.enable = true;
      services.gnome.glib-networking.enable = true;

      # YubiKey touch detector service
      systemd.user.services.yubikey-touch-detector = {
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
    })

    # Audit rules configuration
    (mkIf (cfg.enable && cfg.auditRules.enable) {
      security.auditd.enable = true;
      security.audit.enable = true;
      security.audit.rules = [
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

        # Make configuration immutable (must be last)
        "-e 2"
      ];

      # Disable filter plugin to avoid "line too long" error
      environment.etc."audit/plugins.d/filter.conf".text = mkForce ''
        active = no
      '';

      security.sudo.extraConfig = ''
        Defaults timestamp_timeout=0
        Defaults !tty_tickets
        Defaults log_output
        Defaults log_input
        Defaults logfile=/var/log/sudo.log
      '';
    })
  ];
}
