# YubiKey (Yubico) — per-user GPG and SSH integration.
#
# See ./default.nix for why YubiKey support lives under my/hardware with a
# vendor level.
#
# Imported by ./default.nix rather than listed in platforms/linux.nix, the same
# way my/hardware/laptops/lenovo/legion-16irx8h pulls in its drivers/.
{ activeUsers, config, lib, pkgs, ... }:

with lib;

let
  cfg = config.my.hardware.securityKeys.yubico;
  inherit (config.my.hardware.securityKeys) residentSerials;

  # The keys that live in this machine, when the host says which; otherwise
  # all of them, as before residentSerials existed.
  hereKeys = userCfg:
    let resident = filter (yk: elem yk.serial residentSerials) userCfg.yubikeys;
    in if residentSerials == [ ] then userCfg.yubikeys else resident;
in
{
  config = mkIf cfg.enable {
    # System-level YubiKey support
    services = {
      pcscd.enable = true;
      udev.packages = [ pkgs.yubikey-personalization ];
    };

    # Home-manager configuration for users with YubiKeys
    home-manager.users = mapAttrs
      (name: userCfg:
        let
          hasYubikeys = (length userCfg.yubikeys) > 0;
        in
        mkIf hasYubikeys {
          # Install YubiKey-related packages. Password managers are not key
          # plumbing: they are apps.security.passwords.{pass,gopass,ripasso}.
          home = {
            packages = with pkgs; [

              # Smart GPG wrapper that detects which YubiKey is available
              (pkgs.writeShellScriptBin "gpg-smart" ''
                #!/usr/bin/env bash

                # Detect which YubiKey is available and use the correct key
                ${concatMapStringsSep "\n" (yk: ''
                  if gpg --card-status 2>/dev/null | grep -q "${yk.serial}"; then
                    YUBIKEY_ID="${yk.keyId}"
                  fi
                '') userCfg.yubikeys}

                if [[ -z "$YUBIKEY_ID" ]]; then
                  # No YubiKey detected, use default GPG behavior
                  exec ${pkgs.gnupg}/bin/gpg "$@"
                fi

                # Replace any --local-user with email with our key ID
                args=()
                skip_next=false
                for arg in "$@"; do
                  if [ "$skip_next" = true ]; then
                    # Skip the email argument and replace with our key ID
                    args+=("$YUBIKEY_ID")
                    skip_next=false
                    continue
                  fi

                  if [[ "$arg" == "--local-user" ]]; then
                    args+=("$arg")
                    skip_next=true
                    continue
                  elif [[ "$arg" == --local-user=* ]]; then
                    # Replace the whole argument
                    args+=("--local-user=$YUBIKEY_ID")
                    continue
                  elif [[ "$arg" == "-u" ]]; then
                    args+=("$arg")
                    skip_next=true
                    continue
                  elif [[ "$arg" =~ ^-.*u$ ]]; then
                    # Handle combined arguments like -bsau
                    other_flags="''${arg%u}"
                    if [[ "$other_flags" != "-" ]]; then
                      args+=("$other_flags")
                    fi
                    args+=("--local-user")
                    skip_next=true
                    continue
                  fi

                  args+=("$arg")
                done

                # If no --local-user was specified, add it
                if [[ "$*" != *"--local-user"* && "$*" != *"-u"* && "$*" != *u ]]; then
                  args=("--local-user" "$YUBIKEY_ID" "''${args[@]}")
                fi

                exec ${pkgs.gnupg}/bin/gpg "''${args[@]}"
              '')
            ];

            file = {
              # Helper script for manual GPG key import
              ".local/bin/gpg-import-yubikey" = {
                text = ''
                  #!/usr/bin/env bash
                  echo "Importing YubiKey public keys..."

                  ${concatMapStringsSep "\n" (yk: ''
                    echo "Importing YubiKey ${yk.serial}..."
                    gpg --import ${yk.publicKeyPath}
                    echo "Setting trust level to ultimate for ${yk.keyId}..."
                    echo -e "trust\n5\ny\nsave" | gpg --command-fd 0 --edit-key ${yk.keyId}
                  '') userCfg.yubikeys}

                  echo "All YubiKey public keys imported and trusted!"
                '';
                executable = true;
              };

              # Configure SSH to use YubiKey authentication keys: only the ones
              # that live here, when the host says which. A listed key whose card
              # is absent is still offered, and when the server refuses the
              # present one the agent falls through to it and prompts to insert
              # a card that is in another machine.
              ".gnupg/sshcontrol" = {
                text = concatMapStringsSep "\n"
                  (yk: ''
                    # YubiKey ${yk.serial} authentication keygrip
                    ${yk.sshKeygrip}
                  '')
                  (hereKeys userCfg);
                force = true;
              };

              # The key's half of a pass store: which keys encrypt it (all of
              # them, for redundancy). The store itself, and the tools that
              # read it, are apps.security.passwords.{pass,gopass,ripasso}.
              ".password-store/.gpg-id" = {
                text = concatMapStringsSep "\n" (yk: yk.keyId) userCfg.yubikeys;
                force = true;
              };
            };
          };

          # Automatically import YubiKey public keys on home-manager activation
          # Using systemd service approach since lib.hm.dag is not available in this context
          systemd.user.services.import-yubikey-gpg-keys = {
            Unit = {
              Description = "Import YubiKey GPG public keys";
              After = [ "graphical-session.target" ];
            };
            Service = {
              Type = "oneshot";
              RemainAfterExit = true;
              ExecStart = pkgs.writeShellScript "import-yubikey-keys" ''
                echo "Setting up YubiKey GPG keys..."

                # Ensure GPG home directory exists
                mkdir -p ~/.gnupg
                chmod 700 ~/.gnupg

                # Import current YubiKey keys non-interactively
                ${concatMapStringsSep "\n" (yk: ''
                  if [ -f "${yk.publicKeyPath}" ]; then
                    echo "Importing public key for YubiKey ${yk.serial}..."
                    ${pkgs.gnupg}/bin/gpg --batch --import "${yk.publicKeyPath}" 2>/dev/null || true
                  fi
                '') userCfg.yubikeys}

                # Set trust non-interactively (using fingerprints)
                ${concatMapStringsSep "\n" (yk: ''
                  echo "Setting trust for YubiKey ${yk.serial}..."
                  echo "${yk.fingerprint}:6:" | ${pkgs.gnupg}/bin/gpg --import-ownertrust 2>/dev/null || true
                '') userCfg.yubikeys}

                echo "YubiKey GPG keyring configured successfully"
              '';
            };
            Install.WantedBy = [ "default.target" ];
          };

          # Shell initialization for GPG/SSH
          programs = {
            bash.initExtra = ''
              export SSH_AUTH_SOCK=$(gpgconf --list-dirs agent-ssh-socket)
              GPG_TTY=$(tty 2>/dev/null) && export GPG_TTY
              # Disable GNOME Keyring SSH agent
              unset GNOME_KEYRING_CONTROL
              export DISABLE_GNOME_KEYRING=1
              gpg-connect-agent updatestartuptty /bye >/dev/null 2>&1

              # Update GPG_TTY and notify gpg-agent before each command
              _update_gpg_tty() {
                local _tty
                _tty=$(tty 2>/dev/null) && export GPG_TTY="$_tty"
                gpg-connect-agent updatestartuptty /bye >/dev/null 2>&1
              }
              PROMPT_COMMAND="_update_gpg_tty; ''${PROMPT_COMMAND}"
            '';

            zsh.initContent = ''
              export SSH_AUTH_SOCK=$(gpgconf --list-dirs agent-ssh-socket)
              GPG_TTY=$(tty 2>/dev/null) && export GPG_TTY
              unset GNOME_KEYRING_CONTROL
              export DISABLE_GNOME_KEYRING=1
              gpg-connect-agent updatestartuptty /bye >/dev/null 2>&1
            '';

            # GPG configuration
            gpg = {
              enable = true;

              settings = {
                trust-model = "tofu+pgp";
                use-agent = true;
                verify-options = "show-uid-validity";
                with-fingerprint = true;
                # default-key is single-valued (with several lines gpg silently
                # uses the last), so emit exactly one: the first key that lives
                # here, when the host says which (a default naming a card in
                # another machine asks for that card on every call gpg-smart
                # does not route); else the key marked primary, else the first.
                # Card-aware key selection is gpg-smart's job.
                default-key =
                  let
                    primaries = filter (yk: yk.primary) userCfg.yubikeys;
                    resident = filter (yk: elem yk.serial residentSerials) userCfg.yubikeys;
                  in
                  assert assertMsg (length primaries <= 1)
                    "my.users.${name}.yubikeys: more than one key marked primary";
                  (if resident != [ ] then head resident
                  else if primaries == [ ] then head userCfg.yubikeys
                  else head primaries).keyId;
                default-recipient-self = true;
                auto-key-locate = "local";
                keyid-format = "long";
              };

              # Force scdaemon to use PC/SC for PIV/X.509
              scdaemonSettings = {
                disable-ccid = true;
              };
            };

            # Git GPG signing - use smart wrapper
            git = {
              signing = {
                format = "openpgp";
                signByDefault = true;
                # Use email - smart wrapper will choose the right key
                key = userCfg.email;
              };
              settings = {
                gpg = {
                  # Use smart wrapper that detects available YubiKey
                  program = "gpg-smart";
                  openpgp = {
                    program = "gpg-smart";
                  };
                };
              };
            };

            # Jujutsu GPG signing
            jujutsu = {
              settings = {
                signing = {
                  behavior = "own";
                  backend = "gpg";
                  key = userCfg.email;

                  # jj's gpg backend defaults to `gpg2`, which reaches gnupg
                  # directly: the email resolves to whichever key is listed
                  # first, and gnupg then demands THAT card regardless of which
                  # one is inserted. Route it through the wrapper git already
                  # uses, so on every host the inserted card picks the key.
                  backends.gpg.program = "gpg-smart";
                };
              };
            };
          };

          # GPG agent configuration
          services.gpg-agent = {
            enable = true;
            enableSshSupport = true;
            # Qt pinentry, not GNOME: pinentry-gnome3 draws through the Gcr
            # System Prompter, a D-Bus service that ships with gnome-keyring --
            # which ./default.nix switches OFF, because this profile keeps
            # secrets in pass under the YubiKey instead. With no prompter to
            # reach, that binary announces "No Gcr System Prompter available,
            # falling back to curses" and takes over whichever terminal last
            # ran `updatestartuptty`, which is not necessarily one anybody is
            # looking at. pinentry-qt needs no prompter and has no curses
            # fallback, so a PIN request is a window or an error, never a
            # hijacked session.
            extraConfig = ''
              pinentry-program /run/current-system/sw/bin/pinentry-qt
            '';
            enableExtraSocket = true;
            enableScDaemon = true;

            # THE PRESENCE CHECK LIVES ON THE KEY, NOT HERE. These four cache
            # the PIN; touch policy is what proves a human is present, and it is
            # set per slot with `ykman openpgp keys set-touch <sig|aut|dec>`.
            #
            # They were all 0, under a comment claiming that required a touch for
            # every operation. It did not: measured on this fleet's key, sig and
            # aut were `Touch policy: Off` and only dec was `On`, so for signing
            # and for SSH the zero TTL was the ONLY thing asking for the human --
            # and it asked with a PIN prompt, not a touch. A zero TTL is a
            # retyping tax, not a security control, and it is the weaker of the
            # two: a PIN can be watched, a touch cannot be typed remotely.
            #
            # So the owner's policy is the PIN once per power-up of the key, then
            # no more prompts for as long as it stays plugged in: every TTL is
            # 400 days. These cover the agent's own caches (passphrases, SSH
            # keys); the card's PIN, once given, lasts until the key is
            # unplugged regardless. Unplugging the key is the lock. Kept well
            # under gpg-agent's 2^31-1 second ceiling.
            defaultCacheTtl = 34560000; # 400 days
            maxCacheTtl = 34560000;
            defaultCacheTtlSsh = 34560000;
            maxCacheTtlSsh = 34560000;
          };
        }
      )
      (activeUsers config.my.users);

    # Persistence configuration
    my.system.persistence.features = {
      systemDirectories = [
        "/yubikey"
      ];
      userDirectories = [
        ".gnupg"
        ".yubico"
        ".ssh"
      ];
    };
  };
}
