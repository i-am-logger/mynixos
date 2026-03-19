{ config
, lib
, pkgs
, ...
}:

with lib;

let
  cfg = config.my.network.headscale;
  torCfg = config.my.network.tor;

  onionHostnameFile = "/var/lib/tor/onion/headscale/hostname";

  # Minimal local DERP map — satisfies headscale's requirement for at least one entry
  # Nodes will use direct WireGuard connections; DERP relay is localhost-only (unreachable externally)
  localDerpMap = pkgs.writeText "headscale-derp-map.yaml" ''
    regions:
      999:
        regionid: 999
        regioncode: local
        regionname: Local
        nodes:
          - name: local
            regionid: 999
            hostname: 127.0.0.1
            stunport: -1
            derpport: 0
            stunonly: false
  '';

  aclPolicy = pkgs.writeTextFile {
    name = "headscale-acl-policy.json";
    text = builtins.toJSON ({
      inherit (cfg.acl) groups;
      acls = cfg.acl.rules;
    } // lib.optionalAttrs (cfg.acl.tagOwners != { }) {
      inherit (cfg.acl) tagOwners;
    });
  };
in
{
  config = mkIf cfg.enable {
    services.headscale = {
      enable = true;
      inherit (cfg) address port;
      settings = {
        server_url =
          if cfg.serverUrl != "" then cfg.serverUrl else "http://${cfg.address}:${toString cfg.port}";
        dns = {
          magic_dns = true;
          base_domain = cfg.baseDomain;
          nameservers.global = cfg.nameservers;
        };
        policy.path = toString aclPolicy;
        database = {
          type = "sqlite";
          sqlite.path = "/var/lib/headscale/db.sqlite";
        };
        # Local-only DERP map — no public relays, no metadata leaks
        # Direct WireGuard connections via NAT hole-punching; DERP is a dummy localhost entry
        derp = {
          urls = [ ];
          paths = [ (toString localDerpMap) ];
          auto_update_enabled = false;
        };
        noise.private_key_path = "/var/lib/headscale/noise_private.key";
        prefixes = {
          v4 = "100.64.0.0/10";
          v6 = "fd7a:115c:a1e0::/48";
        };
      };
    };

    systemd.services = {
      # Override server_url at runtime from tor .onion hostname
      headscale-onion-env = mkIf torCfg.onionServices.headscale.enable {
        description = "Generate Headscale env from Tor onion hostname";
        wantedBy = [ "headscale.service" ];
        before = [ "headscale.service" ];
        after = [ "tor.service" ];
        wants = [ "tor.service" ];

        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          RuntimeDirectory = "headscale";
          RuntimeDirectoryMode = "0750";
          User = "root";
          Group = config.services.headscale.group;
        };

        script = ''
          # Wait for tor to generate the .onion hostname
          for i in $(seq 1 60); do
            [ -f ${onionHostnameFile} ] && break
            sleep 1
          done
          if [ ! -f ${onionHostnameFile} ]; then
            echo "ERROR: Tor hostname file not found after 60s: ${onionHostnameFile}" >&2
            exit 1
          fi
          ONION=$(tr -d '[:space:]' < ${onionHostnameFile})
          echo "HEADSCALE_SERVER_URL=http://$ONION:${toString cfg.port}" > /run/headscale/env
          chown ${config.services.headscale.user}:${config.services.headscale.group} /run/headscale/env
          chmod 640 /run/headscale/env
        '';
      };

      headscale = mkIf torCfg.onionServices.headscale.enable {
        after = [ "headscale-onion-env.service" ];
        wants = [ "headscale-onion-env.service" ];
        serviceConfig.EnvironmentFile = [ "-/run/headscale/env" ];
      };

      # Create headscale users after the service starts
      headscale-create-users = mkIf (cfg.users != [ ]) {
        description = "Create Headscale users";
        wantedBy = [ "multi-user.target" ];
        after = [ "headscale.service" ];
        wants = [ "headscale.service" ];

        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          User = config.services.headscale.user;
          Group = config.services.headscale.group;
        };

        script =
          let
            headscale = "${config.services.headscale.package}/bin/headscale";
          in
          ''
            # Wait for headscale socket
            for i in $(seq 1 30); do
              if ${headscale} users list >/dev/null 2>&1; then
                break
              fi
              sleep 1
            done
          ''
          + concatStringsSep "\n" (
            map
              (user: ''
                ${headscale} users list -o json 2>/dev/null | ${pkgs.jq}/bin/jq -e '.[] | select(.name == "${user}")' >/dev/null 2>&1 || \
                  ${headscale} users create ${escapeShellArg user}
              '')
              cfg.users
          );
      };
    };

    # Only open firewall if headscale is not localhost-only
    networking.firewall.allowedTCPPorts = mkIf (cfg.address != "127.0.0.1") [ cfg.port ];

    # Persist headscale state
    my.system.persistence.features.systemDirectories = [
      "/var/lib/headscale"
    ];
  };
}
