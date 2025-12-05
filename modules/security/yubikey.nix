{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.my.features.security;
in
{
  config = mkIf (cfg.enable && cfg.yubikey.enable) {
    # System-level YubiKey support
    services.pcscd.enable = true;
    services.udev.packages = [ pkgs.yubikey-personalization ];

    # Home-manager configuration for users with YubiKeys
    home-manager.users = mapAttrs (name: userCfg:
      let
        hasYubikeys = (length userCfg.yubikeys) > 0;
      in
      mkIf hasYubikeys {
        # Install YubiKey-related packages
        home.packages = with pkgs; [
          gopass
          gopass-jsonapi # Browser integration
          pkgs.passExtensions.pass-import # Import from other password managers

          # Create gpg-import-yubikey script
          (pkgs.writeShellScriptBin "gpg-import-yubikey" ''
            #!/usr/bin/env bash
            echo "Importing YubiKey public keys..."

            ${concatMapStringsSep "\n" (yk: ''
              echo "Importing YubiKey ${yk.serial}..."
              gpg --import ${yk.publicKeyPath}
              echo "Setting trust level to ultimate for ${yk.keyId}..."
              echo -e "trust\n5\ny\nsave" | gpg --command-fd 0 --edit-key ${yk.keyId}
            '') userCfg.yubikeys}

            echo "All YubiKey public keys imported and trusted!"
          '')

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

        # Automatically import YubiKey public keys on home-manager activation
        # Using home.activation without lib.dag since it's not available in this context
        home.file.".gnupg/import-yubikeys.sh" = {
          text = ''
            #!/usr/bin/env bash
            echo "Setting up YubiKey GPG keys..."

            # Delete any keys that are not our current YubiKeys
            for key_id in $(${pkgs.gnupg}/bin/gpg --list-keys --with-colons 2>/dev/null | grep ^pub | cut -d: -f5); do
              ${concatMapStringsSep "\n" (yk: ''
                if [[ "$key_id" == "${yk.keyId}" ]]; then
                  continue
                fi
              '') userCfg.yubikeys}
              echo "Removing old key: $key_id"
              fingerprint=$(${pkgs.gnupg}/bin/gpg --list-keys --with-colons "$key_id" 2>/dev/null | grep ^fpr | cut -d: -f10 | head -1)
              ${pkgs.gnupg}/bin/gpg --batch --yes --delete-secret-and-public-keys "$fingerprint!" 2>/dev/null || true
            done

            # Import current YubiKey keys non-interactively
            ${concatMapStringsSep "\n" (yk: ''
              ${pkgs.gnupg}/bin/gpg --batch --import ${yk.publicKeyPath} 2>/dev/null || true
            '') userCfg.yubikeys}

            # Set trust non-interactively (using fingerprints)
            ${concatMapStringsSep "\n" (yk: ''
              echo "${yk.fingerprint}:6:" | ${pkgs.gnupg}/bin/gpg --import-ownertrust 2>/dev/null || true
            '') userCfg.yubikeys}

            echo "YubiKey GPG keyring cleaned and configured"
          '';
          executable = true;
        };

        # Shell initialization for GPG/SSH
        programs.bash.initExtra = ''
          export SSH_AUTH_SOCK=$(gpgconf --list-dirs agent-ssh-socket)
          export GPG_TTY=$(tty)
          # Disable GNOME Keyring SSH agent
          unset GNOME_KEYRING_CONTROL
          export DISABLE_GNOME_KEYRING=1
          gpg-connect-agent updatestartuptty /bye >/dev/null 2>&1

          # Update GPG_TTY and notify gpg-agent before each command
          _update_gpg_tty() {
            export GPG_TTY=$(tty)
            gpg-connect-agent updatestartuptty /bye >/dev/null 2>&1
          }
          PROMPT_COMMAND="_update_gpg_tty; ''${PROMPT_COMMAND}"
        '';

        programs.zsh.initExtra = ''
          export SSH_AUTH_SOCK=$(gpgconf --list-dirs agent-ssh-socket)
          export GPG_TTY=$(tty)
          unset GNOME_KEYRING_CONTROL
          export DISABLE_GNOME_KEYRING=1
          gpg-connect-agent updatestartuptty /bye >/dev/null 2>&1
        '';

        # GPG configuration
        programs.gpg = {
          enable = true;

          settings = {
            trust-model = "tofu+pgp";
            use-agent = true;
            verify-options = "show-uid-validity";
            with-fingerprint = true;
            # Set all YubiKey keys as default keys - GPG will try them in order
            default-key = map (yk: yk.keyId) userCfg.yubikeys;
            default-recipient-self = true;
            auto-key-locate = "local";
            keyid-format = "long";
          };

          # Force scdaemon to use PC/SC for PIV/X.509
          scdaemonSettings = {
            disable-ccid = true;
          };
        };

        # GPG agent configuration
        services.gpg-agent = {
          enable = true;
          enableSshSupport = true;
          # Use GNOME pinentry for manual PIN entry
          extraConfig = ''
            pinentry-program /run/current-system/sw/bin/pinentry-gnome3
          '';
          enableExtraSocket = true;
          enableScDaemon = true;

          # Disable caching - require YubiKey touch for every operation
          defaultCacheTtl = 0;
          maxCacheTtl = 0;
          defaultCacheTtlSsh = 0;
          maxCacheTtlSsh = 0;
        };

        # Configure SSH to use YubiKey authentication keys
        home.file.".gnupg/sshcontrol" = {
          text = concatMapStringsSep "\n" (yk: ''
            # YubiKey ${yk.serial} authentication keygrip
            ${yk.sshKeygrip}
          '') userCfg.yubikeys;
          force = true;
        };

        # Git GPG signing - use smart wrapper
        programs.git = {
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
        programs.jujutsu = {
          settings = {
            signing = {
              behavior = "own";
              backend = "gpg";
              key = userCfg.email;
            };
          };
        };

        # Password store configuration
        programs.password-store = {
          enable = true;
          package = pkgs.pass.withExtensions (exts: [ exts.pass-otp ]);
          settings = {
            PASSWORD_STORE_DIR = "$HOME/.password-store";
            PASSWORD_STORE_CLIP_TIME = "45";
          };
        };

        # Initialize password store with all YubiKey GPG keys for redundancy
        home.file.".password-store/.gpg-id" = {
          text = concatMapStringsSep "\n" (yk: yk.keyId) userCfg.yubikeys;
          force = true;
        };

        # Gopass configuration with auto-sync
        home.file.".config/gopass/config.yml" = {
          text = ''
            core:
              autopush: true
              autosync: true
              cliptimeout: 45
              exportkeys: true
              notifications: true
              follow-references: false
            pwgen:
              xkcd-lang: en
            mounts:
              path: /home/${name}/.password-store
          '';
          force = true;
        };

        # Browser integration for pass
        programs.browserpass = {
          enable = true;
          browsers = [
            "firefox"
            "chrome"
            "chromium"
            "brave"
          ];
        };

        # Gopass browser integration for Brave
        home.file.".config/BraveSoftware/Brave-Browser/NativeMessagingHosts/com.justwatch.gopass.json" = {
          text = builtins.toJSON {
            name = "com.justwatch.gopass";
            description = "Gopass wrapper to search and return passwords";
            path = "/home/${name}/.config/gopass/gopass_wrapper.sh";
            type = "stdio";
            allowed_origins = [
              "chrome-extension://kkhfnlkhiapbiehimabddjbimfaijdhk/"
            ];
          };
          force = true;
        };

        # Gopass wrapper script for browser integration
        home.file.".config/gopass/gopass_wrapper.sh" = {
          text = ''
            #!/bin/sh

            export PATH="$PATH:$HOME/.nix-profile/bin"
            export PATH="$PATH:/usr/local/bin"
            export PATH="$PATH:/usr/local/MacGPG2/bin"
            export GPG_TTY="$(tty)"

            if [ -f ~/.gpg-agent-info ] && [ -n "$(pgrep gpg-agent)" ]; then
              source ~/.gpg-agent-info
              export GPG_AGENT_INFO
            else
              eval $(gpg-agent --daemon)
            fi

            export PATH="$PATH:/usr/local/bin"

            ${pkgs.gopass-jsonapi}/bin/gopass-jsonapi listen

            exit $?
          '';
          executable = true;
          force = true;
        };
      }
    ) config.my.users;
  };
}
