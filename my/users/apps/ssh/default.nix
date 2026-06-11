{ activeUsers, config, lib, ... }:

with lib;

let
  # Check if user has YubiKeys configured
  hasYubikeys = userCfg: (length (userCfg.yubikeys or [ ])) > 0;
in
{
  # SSH configuration - always enabled for all users
  # This is opinionated: SSH is essential for development and remote access
  config = {
    home-manager.users = mapAttrs
      (_name: userCfg: {
        programs.ssh = {
          enable = true;
          enableDefaultConfig = false;

          # Opinionated host configurations with SSH multiplexing.
          # `settings` is the current API (raw OpenSSH directive names); it
          # replaces the deprecated `matchBlocks` (HM camelCase options).
          settings = {
            "*" = lib.optionalAttrs (!(hasYubikeys userCfg)) {
              # SSH multiplexing disabled for YubiKey users
              # Can cause socket/permission issues with gpg-agent
              # For non-YubiKey users, reuse connections for efficiency
              ControlMaster = "auto";
              ControlPath = "~/.ssh/control-%r@%h:%p";
              ControlPersist = "10m";
            };

            "github.com" = {
              HostName = "github.com";
              User = "git";
              # With YubiKey/gpg-agent, allow agent keys; otherwise restrict to
              # configured identities (IdentitiesOnly) for security.
              IdentitiesOnly = if hasYubikeys userCfg then "no" else "yes";
            };

            "gitlab.com" = {
              HostName = "gitlab.com";
              User = "git";
              IdentitiesOnly = if hasYubikeys userCfg then "no" else "yes";
            };

            "bitbucket.org" = {
              HostName = "bitbucket.org";
              User = "git";
              IdentitiesOnly = if hasYubikeys userCfg then "no" else "yes";
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
      (activeUsers config.my.users);
  };
}
