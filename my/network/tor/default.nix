{ config
, lib
, ...
}:

with lib;

let
  cfg = config.my.network.tor;
  hsCfg = config.my.network.headscale;
in
{
  config = mkIf cfg.enable (mkMerge [
    # Tor onion service for Headscale (auto-enabled when both tor and headscale are enabled)
    (mkIf (cfg.onionServices.headscale.enable || config.services.headscale.enable) {
      services.tor = {
        enable = true;
        relay.onionServices.headscale = {
          version = 3;
          map = [
            {
              inherit (cfg.onionServices.headscale) port;
              target = {
                addr = hsCfg.address;
                inherit (hsCfg) port;
              };
            }
          ];
        };
      };

      # Persist tor state (contains .onion private key)
      my.system.persistence.features.systemDirectories = [
        "/var/lib/tor"
      ];
    })

    # Tor SOCKS client
    (mkIf cfg.client.enable {
      services.tor = {
        enable = true;
        client = {
          enable = true;
          socksListenAddress = {
            addr = "127.0.0.1";
            port = cfg.client.socksPort;
            IsolateDestAddr = true;
          };
        };
      };

      # Persist tor state
      my.system.persistence.features.systemDirectories = [
        "/var/lib/tor"
      ];
    })
  ]);
}
