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

  aclPolicy = pkgs.writeTextFile {
    name = "headscale-acl-policy.json";
    text = builtins.toJSON ({
      groups = cfg.acl.groups;
      acls = cfg.acl.rules;
    } // lib.optionalAttrs (cfg.acl.tagOwners != { }) {
      tagOwners = cfg.acl.tagOwners;
    });
  };
in
{
  config = mkIf cfg.enable {
    services.headscale = {
      enable = true;
      address = cfg.address;
      port = cfg.port;
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
        noise.private_key_path = "/var/lib/headscale/noise_private.key";
        prefixes = {
          v4 = "100.64.0.0/10";
          v6 = "fd7a:115c:a1e0::/48";
        };
      };
    };

    # Override server_url at runtime from tor .onion hostname
    systemd.services.headscale = mkIf torCfg.onionServices.headscale.enable {
      after = [ "tor.service" ];
      wants = [ "tor.service" ];
      serviceConfig.ExecStartPre = [
        "+${pkgs.writeShellScript "headscale-set-onion-url" ''
          # Wait for tor to generate the .onion hostname
          for i in $(seq 1 60); do
            [ -f ${onionHostnameFile} ] && break
            sleep 1
          done
          if [ -f ${onionHostnameFile} ]; then
            ONION=$(cat ${onionHostnameFile} | tr -d '[:space:]')
            echo "HEADSCALE_SERVER_URL=http://$ONION:${toString cfg.port}" > /run/headscale/env
            chown ${config.services.headscale.user}:${config.services.headscale.group} /run/headscale/env
          fi
        ''}"
      ];
      serviceConfig.EnvironmentFile = [ "-/run/headscale/env" ];
    };

    # Create headscale users after the service starts
    systemd.services.headscale-create-users = mkIf (cfg.users != [ ]) {
      description = "Create Headscale users";
      wantedBy = [ "headscale.service" ];
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
              ${headscale} users list 2>/dev/null | grep -q '${user}' || ${headscale} users create ${user}
            '')
            cfg.users
        );
    };

    # Open firewall for headscale
    networking.firewall.allowedTCPPorts = [ cfg.port ];

    # Persist headscale state
    my.system.persistence.features.systemDirectories = [
      "/var/lib/headscale"
    ];
  };
}
