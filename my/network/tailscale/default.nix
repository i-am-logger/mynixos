{ config
, lib
, pkgs
, ...
}:

with lib;

let
  cfg = config.my.network.tailscale;
  hsCfg = config.my.network.headscale;

  # Whether THIS node joins the headscale running on THIS machine. Deliberately
  # not inferred from `hsCfg.enable`: hosting a control server and joining it
  # are independent choices, and conflating them stopped a headscale host from
  # ever joining another tailnet.
  localHeadscale = cfg.controlPlane == "headscale-local";

  localLoginServer = "http://${hsCfg.address}:${toString hsCfg.port}";
in
{
  config = mkIf cfg.enable (mkMerge [
    {
      assertions = [
        {
          assertion = cfg.controlPlane == "headscale-remote" -> cfg.loginServer != "";
          message = "my.network.tailscale.controlPlane = \"headscale-remote\" requires loginServer to be set";
        }
        {
          assertion = cfg.controlPlane != "headscale-remote" -> cfg.loginServer == "";
          message = "my.network.tailscale.loginServer is only used when controlPlane = \"headscale-remote\"";
        }
        {
          # Not fatal for pre-auth keys, only for OAuth client secrets — but we
          # cannot tell which is in the file at eval time, and an untagged
          # OAuth join fails at runtime with an opaque error. Warn loudly here
          # instead, where it is actionable.
          assertion = cfg.authKeyFile != null -> cfg.tags != [ ];
          message = ''
            my.network.tailscale.authKeyFile is set but tags is empty.

            If authKeyFile holds an OAuth client secret (tskey-client-…),
            registration WILL fail: Tailscale requires OAuth-registered nodes
            to be tagged. Set e.g. tags = [ "tag:server" ].

            If it holds a plain pre-auth key (tskey-auth-…), tagging is still
            recommended — tagged nodes do not have their node key expire.
          '';
        }
      ];

      services.tailscale = {
        enable = true;
        inherit (cfg) useRoutingFeatures authKeyParameters;
        extraUpFlags =
          optional (cfg.controlPlane == "headscale-remote")
            "--login-server=${cfg.loginServer}"
          ++ optional cfg.exitNode "--advertise-exit-node"
          ++ optionals (cfg.advertiseRoutes != [ ]) [
            "--advertise-routes=${concatStringsSep "," cfg.advertiseRoutes}"
          ]
          ++ optionals (cfg.tags != [ ]) [
            "--advertise-tags=${concatStringsSep "," cfg.tags}"
          ]
          ++ optional (cfg.authKeyFile != null) "--authkey=file:${cfg.authKeyFile}";

        # The tailnet name follows the machine's hostname, always.
        #
        # A node keeps whatever name it registered with, forever -- the OS
        # hostname is consulted at FIRST registration and never again. A
        # machine that is later renamed therefore keeps its old tailnet
        # identity silently, which is exactly what happened to a radicle
        # builder here: renamed on the host, still listed under the old name
        # on the tailnet, with nothing anywhere reporting the mismatch.
        #
        # extraSetFlags, not extraUpFlags: `tailscaled-autoconnect` only runs
        # when an authKeyFile is set, and the machines on this fleet register
        # interactively. `tailscaled-set` runs regardless, so this converges on
        # every start rather than only at first join.
        extraSetFlags = [ "--hostname=${config.networking.hostName}" ];
      };

      # Allow WireGuard UDP port for tailscale
      networking.firewall.allowedUDPPorts = [ config.services.tailscale.port ];

      # Allow configured TCP ports on tailscale interface (defense in depth over
      # ACLs). Only the ports a consumer ASKED for: a port belongs to the
      # feature that needs it, so sshd's own port is contributed by
      # my/network/openssh and only while sshd is actually running. A role that
      # switches sshd off therefore advertises nothing here.
      networking.firewall.interfaces.tailscale0.allowedTCPPorts = cfg.allowedTCPPorts;


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

      # Keep the Tailscale SSH server on. `tailscale set` is what makes the
      # option durable: it changes only the preference it names, while a
      # hand-run `tailscale up` resets every preference absent from its
      # command line and would silently disable SSH. Waits for the backend
      # because `set` needs a running, logged-in tailscaled; when the node is
      # logged out this exits cleanly and the preference is applied on the
      # next activation after login.
      systemd.services.tailscale-ssh-server = mkIf cfg.ssh {
        description = "Enable the Tailscale SSH server preference";
        wantedBy = [ "multi-user.target" ];
        # Ordered after tailscale-autojoin: its `tailscale up` is itself a
        # preference reset, so running `set` before it would be undone on the
        # boot that joins. systemd ignores ordering against units that do not
        # exist, so this is inert unless controlPlane = "headscale-local".
        after = [ "tailscaled.service" "tailscale-autojoin.service" ];
        wants = [ "tailscaled.service" ];

        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
        };

        path = [ config.services.tailscale.package pkgs.jq ];

        script = ''
          for i in $(seq 1 30); do
            state=$(tailscale status --json 2>/dev/null | jq -r .BackendState 2>/dev/null || true)
            case "$state" in
              Running) tailscale set --ssh=true; exit 0 ;;
              NeedsLogin|Stopped) echo "tailscaled is $state; SSH preference will apply after login"; exit 0 ;;
            esac
            sleep 1
          done
          echo "tailscaled backend not ready after 30s; SSH preference not applied" >&2
          exit 0
        '';
      };
    }

    # Auto-join when headscale is on the same machine
    (mkIf localHeadscale {
      assertions = [
        {
          assertion = hsCfg.users != [ ];
          message = "my.network.headscale.users must have at least one user for tailscale auto-join";
        }
        {
          assertion = hsCfg.enable;
          message = "my.network.tailscale.controlPlane = \"headscale-local\" requires my.network.headscale.enable";
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
              ${optionalString cfg.ssh "--ssh"} \
              ${optionalString cfg.exitNode "--advertise-exit-node"} \
              ${optionalString (cfg.advertiseRoutes != []) "--advertise-routes=${concatStringsSep "," cfg.advertiseRoutes}"}

            # Clean up key file
            rm -f ${keyFile}
          '';
      };
    })
  ]);
}
