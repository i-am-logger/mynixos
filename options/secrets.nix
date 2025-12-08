{ lib, ... }:

{
  options.my.secrets = {
    enable = lib.mkEnableOption "sops-nix secrets management";

    defaultSopsFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = "Default sops file for secrets (usually secrets.yaml in the config repo)";
    };

    sshKeyPaths = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "SSH key paths for sops decryption (age keys derived from SSH)";
    };

    gnupgHome = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "GnuPG home directory for sops (for GPG/YubiKey decryption)";
    };

    ageKeyFile = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Path to age key file for sops decryption";
    };
  };
}
