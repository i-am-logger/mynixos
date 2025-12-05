{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.my.apps;
in
{
  config = mkIf cfg.ssh {
    home-manager.users = mapAttrs (name: userCfg: {
      programs.ssh = {
        enable = true;
        enableDefaultConfig = false;

        # Opinionated host configurations with SSH multiplexing
        matchBlocks = {
          "*" = {
            # Opinionated SSH multiplexing for YubiKey efficiency
            # Reuses connections to avoid repeated YubiKey touches
            controlMaster = "auto";
            controlPath = "~/.ssh/control-%r@%h:%p";
            controlPersist = "10m";
          };

          "github.com" = {
            hostname = "github.com";
            user = "git";
            identitiesOnly = true;
          };

          "gitlab.com" = {
            hostname = "gitlab.com";
            user = "git";
            identitiesOnly = true;
          };

          "bitbucket.org" = {
            hostname = "bitbucket.org";
            user = "git";
            identitiesOnly = true;
          };
        };

        # Use gpg-agent for SSH keys (YubiKey integration)
        extraConfig = ''
          # SSH keys are provided by gpg-agent
          # No need to specify IdentityFile - gpg-agent handles it
        '';
      };

      # Configure gpg-agent SSH support
      services.gpg-agent.enableSshSupport = true;
    }) config.my.users;
  };
}
