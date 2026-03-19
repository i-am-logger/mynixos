{ config
, lib
, ...
}:

with lib;

let
  cfg = config.my.network.openssh;
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

    # Persist host keys across reboots
    my.system.persistence.features.systemDirectories = [
      "/etc/ssh"
    ];
  };
}
