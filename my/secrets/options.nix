{ lib, ... }:

{
  options.my.secrets = {
    enable = lib.mkEnableOption "sops-nix secrets management";

    defaultSopsFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = ''
        Default sops file for secrets.

        This should be a RUNTIME path (a quoted string such as
        "/persist/etc/sops/secrets.yaml"), not a path literal or a flake input,
        both of which nix copies into the store. See `allowSecretsInStore`.
      '';
    };

    allowSecretsInStore = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Permit sops files to live in /nix/store.

        Off by default, because the store is world-readable (`drwxrwxr-t`) and
        permanent: a file placed there is readable by every user and every
        process on the host, cannot be deleted, and travels with `nix copy`.
        Encryption does not make that acceptable — it makes the ciphertext, the
        recipient list and the rotation history public, and any later key
        compromise retroactive.

        The trap this closes is that the exposure is INDIRECT. Interpolating a
        flake input — `defaultSopsFile = "''${secrets}/secrets.yaml"` — copies
        the whole directory the file sits in, so unrelated material beside it
        (stray plaintext, build symlinks) is published too, with nothing in the
        configuration naming it.

        Turning this on restores upstream sops-nix behaviour, including its
        eval-time hash check, for the ordinary pattern of committing encrypted
        files next to the configuration that reads them.
      '';
    };

    sshKeyPaths = lib.mkOption {
      type = lib.types.listOf lib.types.nonEmptyStr;
      default = [ ];
      description = "SSH key paths for sops decryption (age keys derived from SSH)";
    };

    gnupgHome = lib.mkOption {
      type = lib.types.nullOr lib.types.nonEmptyStr;
      default = null;
      description = "GnuPG home directory for sops (for GPG/YubiKey decryption)";
    };

    ageKeyFile = lib.mkOption {
      type = lib.types.nullOr lib.types.nonEmptyStr;
      default = null;
      description = "Path to age key file for sops decryption";
    };
  };
}
