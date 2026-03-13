{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.my.secrets;
in
{
  config = mkIf cfg.enable {
    # Persistence configuration
    my.system.persistence.features = {
      userDirectories = [
        ".secrets"
      ];
    };

    # Configure sops-nix
    sops = {
      defaultSopsFile = mkIf (cfg.defaultSopsFile != null) cfg.defaultSopsFile;

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
