# YubiKey (Yubico) — system-level device support.
#
# This lives under my/hardware because it is device wiring. It sets
# services.pcscd, services.udev.packages, hardware.gpgSmartcards, PAM and the
# gnupg agent for a physical key you plug in — the same shape as
# my/hardware/bluetooth/realtek, which also does its own services.* wiring.
# my/security keeps what is genuinely device-independent policy: secure boot,
# TPM, audit rules, sudo.
#
# The vendor level is deliberate: every other my/hardware entry names a vendor
# (realtek, nzxt, intel, nvidia, gigabyte, lenovo, elgato, keychron). The old
# path named the PRODUCT (yubikey); Yubico is the vendor. mynixos already
# enumerates exactly these three in lib.securityKeys — yubikey, solokey,
# nitrokey — so sibling vendor directories have somewhere to go.
#
# Gating is `my.hardware.securityKeys.yubico.enable` alone, deliberately not
# conjoined with `my.security.enable`: hardware support does not depend on the
# security feature bundle.
{ activeUsers, config, lib, pkgs, ... }:

with lib;

let
  cfg = config.my.hardware.securityKeys.yubico;

  # A user carrying yubikey serials implies they need the device support, even
  # if the host never set the flag explicitly.
  #
  # NOTE: `attrValues config.my.users`, NOT `activeUsers`. activeUsers filters to
  # users that have a fullName, so using it here would silently stop partial
  # entries (yubikeys/mounts only) from pulling in device support.
  hasYubikey = any (user: (length user.yubikeys) > 0)
    (attrValues config.my.users);

  enabled = cfg.enable || hasYubikey;
in
{
  imports = [ ./gpg.nix ];

  config = mkIf enabled {
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
        pinentry-qt
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
          # SDDM's helper cannot answer the fleet's INTERACTIVE pam_u2f
          # prompt ("insert your key, then press ENTER") — its theme API is
          # sddm.login(user, password, session), with PAM info messages
          # surfacing only as text. Password login at the greeter; the key
          # stays required for sudo, TTY login and the session lock.
          sddm.u2fAuth = lib.mkDefault false;
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
        pinentryPackage = pkgs.pinentry-qt;
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
  };
}
