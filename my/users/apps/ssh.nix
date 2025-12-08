{ config, lib, pkgs, ... }:

with lib;

let
  # Check if user has YubiKeys configured
  hasYubikeys = userCfg: (length (userCfg.yubikeys or [])) > 0;
in
{
  # SSH configuration - always enabled for all users
  # This is opinionated: SSH is essential for development and remote access
  config = {
    home-manager.users = mapAttrs
      (name: userCfg: {
        programs.ssh = {
          enable = true;
          enableDefaultConfig = false;

          # Opinionated host configurations with SSH multiplexing
          matchBlocks = {
            "*" = lib.optionalAttrs (!(hasYubikeys userCfg)) {
              # SSH multiplexing disabled for YubiKey users
              # Can cause socket/permission issues with gpg-agent
              # For non-YubiKey users, reuse connections for efficiency
              controlMaster = "auto";
              controlPath = "~/.ssh/control-%r@%h:%p";
              controlPersist = "10m";
            };

            "github.com" = {
              hostname = "github.com";
              user = "git";
              # When using YubiKey/gpg-agent, allow agent keys
              # Otherwise use default behavior (identitiesOnly = true for security)
              identitiesOnly = !(hasYubikeys userCfg);
            };

            "gitlab.com" = {
              hostname = "gitlab.com";
              user = "git";
              identitiesOnly = !(hasYubikeys userCfg);
            };

            "bitbucket.org" = {
              hostname = "bitbucket.org";
              user = "git";
              identitiesOnly = !(hasYubikeys userCfg);
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
      })
      config.my.users;
  };
}
