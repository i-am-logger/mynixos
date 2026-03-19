{ config
, lib
, pkgs
, ...
}:

with lib;

let
  cfg = config.my.network.tailscale;
  hsCfg = config.my.network.headscale;

  # Detect if headscale is running on the same machine
  localHeadscale = hsCfg.enable;

  localLoginServer = "http://${hsCfg.address}:${toString hsCfg.port}";
  authKeyFile = "/run/tailscale/authkey";
in
{
  config = mkIf cfg.enable (mkMerge [
    {
      services.tailscale = {
        enable = true;
        useRoutingFeatures = cfg.useRoutingFeatures;
        extraUpFlags =
          optional (cfg.loginServer != "") "--login-server=${cfg.loginServer}"
          ++ optional cfg.exitNode "--advertise-exit-node"
          ++ optionals (cfg.advertiseRoutes != [ ]) [
            "--advertise-routes=${concatStringsSep "," cfg.advertiseRoutes}"
          ]
          ++ optional (cfg.authKeyFile != null) "--authkey=file:${cfg.authKeyFile}";
      };

      # Trust the tailscale interface
      networking.firewall.trustedInterfaces = [ "tailscale0" ];

      # Enable UDP GRO forwarding on all physical interfaces for tailscale throughput
      boot.kernel.sysctl."net.core.rmem_max" = lib.mkDefault 7500000;
      boot.kernel.sysctl."net.core.wmem_max" = lib.mkDefault 7500000;
      systemd.services.tailscale-udp-gro = {
        description = "Enable UDP GRO forwarding for Tailscale";
        wantedBy = [ "multi-user.target" ];
        before = [ "tailscaled.service" ];
        after = [ "network-pre.target" ];
        serviceConfig.Type = "oneshot";
        serviceConfig.RemainAfterExit = true;
        path = [ pkgs.ethtool pkgs.findutils ];
        script = ''
          for iface in /sys/class/net/*; do
            name=$(basename "$iface")
            [ "$name" = "lo" ] && continue
            [ -d "$iface/device" ] || continue
            ethtool -K "$name" rx-udp-gro-forwarding on rx-gro-list off 2>/dev/null || true
          done
        '';
      };

      # Persist tailscale state
      my.system.persistence.features.systemDirectories = [
        "/var/lib/tailscale"
      ];
    }

    # Auto-join when headscale is on the same machine
    (mkIf localHeadscale {
      assertions = [
        {
          assertion = hsCfg.users != [ ];
          message = "my.network.headscale.users must have at least one user for tailscale auto-join";
        }
        {
          assertion = cfg.loginServer == "";
          message = "my.network.tailscale.loginServer conflicts with local headscale auto-join (remove loginServer)";
        }
      ];

      systemd.services.tailscale-autojoin = {
        description = "Auto-join local Headscale mesh";
        wantedBy = [ "multi-user.target" ];
        after = [ "headscale.service" "headscale-create-users.service" "tailscaled.service" ];
        wants = [ "headscale.service" "headscale-create-users.service" "tailscaled.service" ];

        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          RuntimeDirectory = "tailscale-autojoin";
          RuntimeDirectoryMode = "0700";
        };

        path = [ config.services.tailscale.package ];

        script =
          let
            headscale = "${config.services.headscale.package}/bin/headscale";
            tailscale = "${config.services.tailscale.package}/bin/tailscale";
            jq = "${pkgs.jq}/bin/jq";
            user = builtins.head hsCfg.users;
            keyFile = "/run/tailscale-autojoin/authkey";
          in
          ''
            # Skip if already connected
            if ${tailscale} status --json 2>/dev/null | ${jq} -e '.Self.Online' >/dev/null 2>&1; then
              echo "Already connected to tailnet, skipping"
              exit 0
            fi

            # Wait for headscale to be ready
            for i in $(seq 1 30); do
              if ${headscale} users list >/dev/null 2>&1; then
                break
              fi
              sleep 1
            done

            # Look up user ID by name (headscale v0.28+ uses numeric IDs)
            USER_ID=$(${headscale} users list -o json | ${jq} -r '.[] | select(.name == "${user}") | .id')
            if [ -z "$USER_ID" ]; then
              echo "User '${user}' not found in headscale"
              exit 1
            fi

            # Generate a pre-auth key and write to file (avoid leaking via cmdline)
            ${headscale} preauthkeys create --user "$USER_ID" --expiration 5m > ${keyFile}
            chmod 600 ${keyFile}

            ${tailscale} up \
              --login-server=${localLoginServer} \
              --authkey=file:${keyFile} \
              ${optionalString cfg.exitNode "--advertise-exit-node"} \
              ${optionalString (cfg.advertiseRoutes != []) "--advertise-routes=${concatStringsSep "," cfg.advertiseRoutes}"}

            # Clean up key file
            rm -f ${keyFile}
          '';
      };
    })
  ]);
}
