{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.my.features.security;

  # Check if any user has a yubikey passkey
  hasYubikey = any (user: user.passkey != null && user.passkey.type or null == "yubikey")
    (attrValues config.my.features.users);

  # Get all yubikey users
  yubikeyUsers = filter (user: user.passkey != null && user.passkey.type or null == "yubikey")
    (attrValues config.my.features.users);
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

      # Add persistence for secure boot keys
      environment.persistence."/persist".directories = mkIf (config.fileSystems ? "/persist")
        [ "/var/lib/sbctl" ];

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
        "-a exit,always -F arch=b64 -F euid=0 -S execve"
        "-a exit,always -F arch=b32 -F euid=0 -S execve"
      ];

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
