{ activeUsers
, config
, lib
, ...
}:

with lib;

let
  cfg = config.my.network.openssh;

  # Collect SSH public keys from all users' YubiKeys
  usersWithKeys = filterAttrs
    (_: userCfg: (length userCfg.yubikeys) > 0)
    config.my.users;
in
{
  # Auto-enable when tailscale is enabled
  config = mkIf (cfg.enable || config.services.tailscale.enable) {
    services.openssh = {
      enable = true;
      openFirewall = false; # never open globally — consumers decide which interfaces
      hostKeys = [
        { path = "/etc/ssh/ssh_host_ed25519_key"; type = "ed25519"; }
      ];
      settings = {
        PasswordAuthentication = false;
        KbdInteractiveAuthentication = false;
        PermitRootLogin = "no";
        AuthenticationMethods = "publickey";
      };
    };

    # Set authorized_keys from YubiKey SSH public keys
    users.users = mapAttrs
      (name: userCfg: {
        openssh.authorizedKeys.keys =
          filter (k: k != "")
            (map (yk: yk.sshPublicKey) userCfg.yubikeys);
      })
      usersWithKeys;

    # Persist host keys across reboots
    my.system.persistence.features.systemDirectories = [
      "/etc/ssh"
    ];
  };
}
