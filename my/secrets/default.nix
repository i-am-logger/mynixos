{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.my.secrets;

  # A path is "in the store" whether it arrived as a path literal, a flake
  # input, or a string that already carries the prefix -- `toString` flattens
  # all three to the same thing, which is exactly the point: the leak does not
  # announce which form produced it.
  inStore = p: hasPrefix builtins.storeDir (toString p);

  storeBackedSecrets = filter (s: inStore s.sopsFile) (attrValues config.sops.secrets);

  # Written once and shared, because the two assertions differ only in what
  # they are pointing at and the reasoning is the whole value of the message.
  why = ''
    /nix/store is world-readable (drwxrwxr-t) and permanent: anything placed
    there can be read by every user and every process on this host, cannot be
    removed by deleting the source, and is carried along by `nix copy`.

    Encryption is not a defence against publication -- it exposes the
    ciphertext, the recipient list and the rotation history, and makes any
    future compromise of a recipient key retroactive over every version ever
    built.

    Point this at a runtime path this host owns, as a QUOTED STRING:

        my.secrets.defaultSopsFile = "/persist/etc/sops/secrets.yaml";

    A path literal (/persist/etc/...) or a flake input is copied into the store
    and puts you straight back here. Interpolating an input is the worst of the
    three, because it copies the whole DIRECTORY the file sits in -- publishing
    whatever else happens to be beside it, named nowhere in your configuration.

    If you genuinely want encrypted secrets committed beside the configuration
    that reads them, say so explicitly with:

        my.secrets.allowSecretsInStore = true;
  '';
in
{
  config = mkIf cfg.enable {
    assertions =
      (optional (cfg.ageKeyFile != null) {
        assertion = hasPrefix "/" cfg.ageKeyFile;
        message = "my.secrets.ageKeyFile must be an absolute path, got: ${cfg.ageKeyFile}";
      })
      ++ (optional (cfg.gnupgHome != null) {
        assertion = hasPrefix "/" cfg.gnupgHome;
        message = "my.secrets.gnupgHome must be an absolute path, got: ${cfg.gnupgHome}";
      })
      ++ (map
        (path: {
          assertion = hasPrefix "/" path;
          message = "my.secrets.sshKeyPaths entries must be absolute paths, got: ${path}";
        })
        cfg.sshKeyPaths)

      # The store-path policy. Both halves are needed: the first catches the
      # fleet-wide default, the second catches a single `sops.secrets.<n>.sopsFile`
      # override, which bypasses my.secrets entirely and is the easier one to
      # add without thinking about where it lands.
      ++ (optional (!cfg.allowSecretsInStore && cfg.defaultSopsFile != null && inStore cfg.defaultSopsFile) {
        assertion = false;
        message = ''
          my.secrets.defaultSopsFile is in /nix/store:

            ${toString cfg.defaultSopsFile}

          ${why}'';
      })
      ++ (optional (!cfg.allowSecretsInStore && storeBackedSecrets != [ ]) {
        assertion = false;
        message = ''
          These sops.secrets read a file in /nix/store:

          ${concatMapStringsSep "\n" (s: "  sops.secrets.${s.name}.sopsFile = ${toString s.sopsFile}") storeBackedSecrets}

          ${why}'';
      });

    # Configure sops-nix
    sops = {
      defaultSopsFile = mkIf (cfg.defaultSopsFile != null) cfg.defaultSopsFile;

      # sops-nix validates by hashing the file at EVALUATION time, which is
      # only possible for a store path -- so its validation and the policy
      # above are the same switch seen from two sides, not two decisions. With
      # secrets at a runtime path there is nothing to hash: the file is not
      # required to exist, or to be readable, until activation.
      validateSopsFiles = cfg.allowSecretsInStore;

      # Age key configuration
      age = {
        keyFile = mkIf (cfg.ageKeyFile != null) cfg.ageKeyFile;
        inherit (cfg) sshKeyPaths;
      };

      # GPG/YubiKey configuration
      gnupg = mkIf (cfg.gnupgHome != null) {
        home = cfg.gnupgHome;
        sshKeyPaths = [ ]; # Don't use SSH keys when using GPG
      };
    };

    # Ensure sops CLI is available
    environment.systemPackages = [ pkgs.sops ];
  };
}
