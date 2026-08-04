# Hardware security keys / authentication tokens — Linux only.
#
# This is a scope decision, not a technical limit. A YubiKey works on macOS: GPG
# commit signing, SSH authentication and pass/gopass decryption all function
# there, because macOS ships its own CCID smartcard driver. What does not port is
# this module's IMPLEMENTATION — services.pcscd, services.udev.packages and the
# NixOS security.pam surface are the bulk of it, and nix-darwin has none of them.
#
# aether5d-dev authenticates sudo with Touch ID and carries a Secure Enclave SSH
# key, so a YubiKey there is a second mechanism for something already covered.
# See docs/yubikey-on-darwin.md for what supporting it would take.
#
# Declared here rather than in ../options.nix so the option does not exist on
# darwin: setting it there fails with "The option `my.hardware.securityKeys' does
# not exist" instead of silently doing nothing. `types.submodule` declarations
# for the same option merge, so this composes with the cross-platform
# `my.hardware` options.
{ lib, ... }:

{
  hardware = lib.mkOption {
    type = lib.types.submodule {
      options = {
        # Hardware authentication tokens. A standard YubiKey is a POSSESSION
        # factor (touch presence + PIV/GPG/FIDO), not a biometric — only the
        # YubiKey Bio has a fingerprint sensor — so it is a sibling of
        # `biometrics` rather than part of it.
        #
        # Vendor-keyed to match the rest of this tree. mynixos already enumerates
        # yubikey/solokey/nitrokey in lib.securityKeys, so solokeys and nitrokey
        # have obvious homes alongside yubico.
        securityKeys = lib.mkOption {
          description = "Hardware security keys / authentication tokens";
          default = { };
          type = lib.types.submodule {
            options = {
              yubico = lib.mkOption {
                description = "YubiKey support (pcscd, udev, PAM, gnupg agent)";
                default = { };
                type = lib.types.submodule {
                  options = {
                    enable = lib.mkEnableOption "yubikey support";
                  };
                };
              };
            };
          };
        };
      };
    };
  };
}
