{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.my.secrets;
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
        cfg.sshKeyPaths);

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
