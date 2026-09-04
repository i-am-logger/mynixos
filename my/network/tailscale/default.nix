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
        inherit (cfg) port useRoutingFeatures authKeyParameters;
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
        extraSetFlags =
          [ "--hostname=${config.networking.hostName}" ]
          ++ optional (cfg.relayServerPort != null)
            "--relay-server-port=${toString cfg.relayServerPort}";
      };

      # Allow WireGuard UDP port for tailscale. Skipped when the port is 0:
      # tailscaled then takes whatever the kernel gives it, so there is no fixed
      # number to open -- and opening 0 is not a rule, it is a mistake that
      # happens to be silent.
      networking.firewall.allowedUDPPorts =
        optional (config.services.tailscale.port != 0) config.services.tailscale.port;

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

    # LIVENESS -- prove a ROUND TRIP over the tailnet, and keep the failures a
    # restart can fix apart from the ones it cannot.
    #
    # `tailscaled` being up is not the same fact as this node being reachable.
    # When the datapath under it dies the process stays alive against an
    # interface nothing reads: unit `active`, zero restarts, registration
    # intact, `systemctl --failed` empty, and the node off the tailnet for
    # hours. Nothing above notices, because everything above only ever ordered
    # itself after tailscaled.service and never looked again.
    #
    # So the probe measures reachability instead of inferring it, and the
    # verdict is three-way rather than pass/fail, because the three cases want
    # three different responses:
    #
    #   no peer answers          this node is off the tailnet -- a restart is
    #                            a plausible repair, so on a role this
    #                            escalates (platforms/oci-variant.nix arms it)
    #   some answer, some do not this node is ON the tailnet and a named peer
    #                            is unreachable -- restarting cannot fix
    #                            someone else's outage, so it fails the unit
    #   nothing could be read    the probe did not establish anything; still a
    #                            failure, never a pass, but never an escalation
    #
    # Deliberately container-agnostic: on a host a failing probe is a failed
    # unit and nothing more.
    (mkIf cfg.liveness.enable (
      let
        # `peers` is a listOf, so definitions CONCATENATE: my/infra/radicle
        # derives the node a role dials from its own `connect` list, and the
        # role's own file adds the ones nothing can infer. A peer named by both
        # would otherwise be pinged twice and counted twice, so it is collapsed
        # once here rather than at each contributor.
        peers = unique cfg.liveness.peers;

        # Derived, not left to DefaultTimeoutStartSec (90s here). A run's worst
        # case is retries x (a status read, one ping per peer, a second status
        # read) plus the sleeps between attempts; widening retries/retryDelay
        # past 90s would otherwise SIGTERM every run on a healthy node and
        # report a start timeout instead of a peer result.
        budget =
          cfg.liveness.retries * (15 + 6 * (length peers))
          + (cfg.liveness.retries - 1) * cfg.liveness.retryDelay
          + 30;
      in
      {
        assertions = [
          {
            assertion = cfg.liveness.peers != [ ];
            message = ''
              my.network.tailscale.liveness.enable is on with liveness.peers = [ ].

              The probe exists to tell "tailscaled is running" from "this node
              can reach the tailnet", and only a round trip to something else
              tells them apart. With no peer to reach, every run would report
              healthy on exactly the failure the probe was added to catch.
            '';
          }
        ];

        systemd = {
          services.tailnet-liveness = {
            description = "Prove this node still has a path onto the tailnet";
            after = [ "tailscaled.service" ];
            wants = [ "tailscaled.service" ];

            # NOT wantedBy anything: the timer is what runs it, and a unit that
            # also ran at boot would take its verdict before tailscaled had a
            # netmap.

            path = [ config.services.tailscale.package pkgs.jq ];

            serviceConfig = {
              Type = "oneshot";

              # No RemainAfterExit. The timer re-arms from OnUnitInactiveSec, and
              # a oneshot that stays `active (exited)` never goes inactive -- the
              # pairing that left my/system/unique-ids' hourly drift check
              # running exactly once per boot.
              TimeoutStartSec = "${toString budget}s";

              # The probe must not be the first thing killed by pressure it is
              # not the cause of. Inside a builder, repository-supplied shell can
              # drive the cgroup to its `memory` ceiling or its `pidsLimit`, and
              # the probe losing that race is a guest-local event being reported
              # as an unreachable tailnet. A rootless role cannot LOWER
              # oom_score_adj -- that wants CAP_SYS_RESOURCE, which is not in its
              # bounding set -- and systemd skips the directive on EPERM instead
              # of failing the unit, so MemoryMin is what carries there and
              # OOMScoreAdjust is what carries on a host.
              OOMScoreAdjust = -900;
              MemoryMin = "32M";

              # Nothing else belongs here, and each absence is load-bearing:
              #   * no Restart= -- hysteresis is inside the script, and a restart
              #     would retry the unit instead of letting the run reach a
              #     verdict;
              #   * no Condition*= -- a skipped unit makes no state transition,
              #     so the FailureAction a role attaches would never fire. That
              #     is the quietest way to switch this whole design off;
              #   * no Protect*/PrivateTmp/confinement -- those are mounts, and a
              #     rootless role has no CAP_SYS_ADMIN to make them with. Some
              #     report ENOANO and are ignored, but the ones that do not fail
              #     the unit at NAMESPACE in every role at once.
            };

            script =
              let
                peerArgs = escapeShellArgs peers;
                systemctl = "${config.systemd.package}/bin/systemctl";
              in
              ''
                status=""

                # Every read of tailscaled's own view goes through here. An
                # unreadable or unparseable status is NOT a pass -- a guard that
                # passes because it could not run is the failure it exists to
                # catch (my/system/unique-ids) -- but it is a different verdict
                # from a dead datapath, and gets a different consequence.
                read_status() {
                  status=$(tailscale status --json 2>/dev/null) || return 1
                  printf '%s' "$status" | jq -e 'has("BackendState")' >/dev/null 2>&1
                }

                # Out of OUR OWN netmap, never DNS: in a container
                # /etc/resolv.conf points at the rootless network helper's
                # forwarder, which is one of the things whose death this probe is
                # for. DNSName is matched before HostName because HostName is not
                # unique on a real tailnet -- phones report `localhost`.
                peer_ip() {
                  printf '%s' "$status" | jq -r --arg p "$1" '
                    def ip: (.TailscaleIPs // [])[0];
                    ( [ .Peer[]? | select((.DNSName // "") | startswith($p + ".")) | ip ]
                    + [ .Peer[]? | select(.HostName == $p)                        | ip ] )
                    | map(select(. != null)) | first // empty'
                }

                # 0 every peer answered | 13 some did | 10 none did
                # 11 the backend is not Running | 12 the probe could not run
                attempt() {
                  read_status || return 12

                  state=$(printf '%s' "$status" | jq -r '.BackendState // "unknown"')
                  if [ "$state" != "Running" ]; then
                    # NeedsLogin, Stopped, a revoked or de-tagged node, an
                    # expired key, a control-plane outage. All real, none of them
                    # a dead datapath, and no restart repairs any of them -- it
                    # destroys the hand-run `tailscale up` a fresh
                    # /var/lib/tailscale needs. tailscale-ssh-server above draws
                    # the same line through the same states.
                    echo "tailscaled BackendState=$state: not a datapath verdict" >&2
                    return 11
                  fi

                  answered=0
                  silent=0
                  for peer in ${peerArgs}; do
                    ip=$(peer_ip "$peer") || ip=""
                    if [ -z "$ip" ]; then
                      echo "peer $peer is absent from this node's netmap" >&2
                      silent=$((silent + 1))
                      continue
                    fi
                    # --until-direct=false because these nodes have no reachable
                    # UDP endpoint and relay via DERP; insisting on a direct path
                    # would fail on a healthy one.
                    if tailscale ping --c 1 --until-direct=false --timeout 5s "$ip" >/dev/null 2>&1; then
                      answered=$((answered + 1))
                    else
                      echo "peer $peer ($ip) did not answer" >&2
                      silent=$((silent + 1))
                    fi
                  done

                  if [ "$silent" -eq 0 ]; then
                    return 0
                  fi
                  if [ "$answered" -gt 0 ]; then
                    return 13
                  fi

                  # Nobody answered. Before calling the datapath dead -- the one
                  # verdict that may take a container down -- prove this process
                  # can still fork and exec and that tailscaled still answers, so
                  # guest-local memory or pid pressure cannot present itself as
                  # an unreachable tailnet.
                  read_status || return 12
                  if [ "$(printf '%s' "$status" | jq -r '.BackendState // "unknown"')" != "Running" ]; then
                    return 11
                  fi
                  return 10
                }

                # The run's verdict, not any single attempt's: it escalates only
                # when EVERY attempt agreed that nothing answered. Any attempt
                # that could not run, or that found the backend elsewhere than
                # Running, takes escalation off the table for the whole run --
                # mixed evidence is not evidence of a dead datapath.
                worst=10
                i=1
                while [ "$i" -le ${toString cfg.liveness.retries} ]; do
                  rc=0
                  attempt || rc=$?
                  case "$rc" in
                    0) exit 0 ;;
                    10) ;;
                    *) worst=$rc ;;
                  esac
                  if [ "$i" -lt ${toString cfg.liveness.retries} ]; then
                    sleep ${toString cfg.liveness.retryDelay}
                  fi
                  i=$((i + 1))
                done

                # Logged, never gated on: .Self.Online is read out of the netmap,
                # which is stale exactly when the control plane is unreachable,
                # so it can report true through an entire outage. .Health is
                # advisory and has only ever been observed empty here.
                if [ -n "$status" ]; then
                  printf '%s' "$status" \
                    | jq -c '{BackendState, Health, Self: {Online: .Self.Online, DNSName: .Self.DNSName}}' >&2 \
                    || true
                fi

                if [ "$worst" -eq 10 ]; then
                  echo "no configured peer answered in ${toString cfg.liveness.retries} attempts while tailscaled reported Running: this node is off the tailnet" >&2
                  ${systemctl} --no-block start tailnet-datapath-dead.service || true
                  exit 1
                fi

                case "$worst" in
                  13) echo "on the tailnet, but a named peer stayed unreachable: not this node's failure to restart away" >&2 ;;
                  11) echo "tailscaled is not Running: a restart repairs none of the states that produce this" >&2 ;;
                  12) echo "could not read tailscaled's status: failing the unit rather than calling the tailnet dead" >&2 ;;
                esac
                exit 1
              '';
          };

          # THE ESCALATION POINT, a unit of its own on purpose.
          #
          # FailureAction= fires on ANY failure of the unit carrying it, so a
          # probe that carried it could not tell "no peer answered" from "the
          # probe could not run". The second is reachable from inside a builder
          # by ordinary means -- an in-cgroup OOM kill landing on jq, a fork
          # refused at pidsLimit -- and it would convert a contained guest-local
          # event into a host action: a full guest reboot, on a ~4-minute period,
          # for as long as the pressure lasts. Arming a unit that runs ONLY on
          # the no-peer-answered verdict keeps the other one a failed unit.
          #
          # No FailureAction here: this module runs on hosts too, where the pair
          # is simply two entries in `systemctl --failed`.
          # platforms/oci-variant.nix is what arms it for roles.
          services.tailnet-datapath-dead = {
            description = "Tailnet datapath confirmed dead (escalation point for tailnet-liveness)";
            serviceConfig.Type = "oneshot";
            script = ''
              echo "tailnet-liveness found no configured peer reachable while tailscaled reported Running." >&2
              echo "The per-peer results are in the tailnet-liveness entries just above." >&2
              exit 1
            '';
          };

          timers.tailnet-liveness = {
            description = "Run the tailnet round-trip probe";
            wantedBy = [ "timers.target" ];
            timerConfig = {
              OnBootSec = cfg.liveness.startDelay;
              # From the probe going INACTIVE, never OnUnitActiveSec: a run that
              # takes longer than the interval would otherwise re-trigger the
              # moment it finished, and the OnUnitActiveSec/RemainAfterExit
              # pairing is what silently stopped my/system/unique-ids' timer.
              OnUnitInactiveSec = cfg.liveness.interval;
              AccuracySec = "10s";
              Unit = "tailnet-liveness.service";
            };
          };
        };
      }
    ))

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
