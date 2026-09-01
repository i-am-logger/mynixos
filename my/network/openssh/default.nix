{ config
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
  config = mkMerge [
    # Auto-enable when tailscale is enabled
    (mkIf (cfg.enable || config.services.tailscale.enable) {
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
        (_: userCfg: {
          openssh.authorizedKeys.keys =
            filter (k: k != "")
              (map (yk: yk.sshPublicKey) userCfg.yubikeys);
        })
        usersWithKeys;

      # Persist host keys across reboots
      my.system.persistence.features.systemDirectories = [
        "/etc/ssh"
      ];
    })

    # The port belongs to the feature that needs it: sshd's reachability on the
    # tailnet is opened HERE, not in my/network/tailscale, and only while sshd is
    # actually running. A role that switches sshd off (platforms/oci.nix) then
    # advertises nothing on tailscale0 — which is what the container roles want.
    #
    # THE GATE MATTERS. Contributing to `my.network.tailscale.allowedTCPPorts`
    # from this module instead is an infinite recursion, and not an obvious one:
    # `my.network` is ONE option of submodule type (my/network/options.nix loaded
    # through mkOptionsModule), so reading any leaf under it merges every
    # definition of the whole submodule — which would force this module's own
    # `mkIf` condition, which reads `services.tailscale.enable`, which is defined
    # under `mkIf config.my.network.tailscale.enable`, which forces `my.network`
    # again. Writing the plain NixOS option directly has no such aggregation, and
    # gating on `services.openssh.enable` — the thing that decides whether a
    # daemon is listening — keeps the dependency pointing one way.
    (mkIf (config.services.openssh.enable && config.services.tailscale.enable) {
      networking.firewall.interfaces.tailscale0.allowedTCPPorts =
        config.services.openssh.ports;
    })
  ];
}
