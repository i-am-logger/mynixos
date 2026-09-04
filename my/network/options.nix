{ lib, ... }:

{
  network = lib.mkOption {
    description = "Network configuration (mesh VPN, Tor, monitoring)";
    default = { };
    type = lib.types.submodule {
      options = {
        openssh = {
          enable = lib.mkEnableOption "OpenSSH server (pubkey-only, no root login)";
        };

        headscale = {
          enable = lib.mkEnableOption "Headscale coordination server (self-hosted Tailscale control plane)";


          serverUrl = lib.mkOption {
            type = lib.types.str;
            default = "";
            description = "Public URL for the Headscale server (e.g. http://<onion>.onion:8080). Set after first boot.";
          };

          port = lib.mkOption {
            type = lib.types.port;
            default = 8080;
            description = "Port for the Headscale gRPC/HTTP listener";
          };

          address = lib.mkOption {
            type = lib.types.str;
            default = "127.0.0.1";
            description = "Listen address for Headscale";
          };

          baseDomain = lib.mkOption {
            type = lib.types.str;
            default = "tailnet";
            description = "Base domain for MagicDNS";
          };

          nameservers = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [ "1.1.1.1" "9.9.9.9" ];
            description = "DNS nameservers for the tailnet";
          };

          users = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [ ];
            description = "Headscale users to create on startup";
          };

          acl = {
            groups = lib.mkOption {
              type = lib.types.attrsOf (lib.types.listOf lib.types.str);
              default = { };
              description = "ACL groups mapping group names to user lists";
            };

            tagOwners = lib.mkOption {
              type = lib.types.attrsOf (lib.types.listOf lib.types.str);
              default = { };
              description = "Tag owners mapping tag names to groups/users who can assign them";
            };

            rules = lib.mkOption {
              type = lib.types.listOf lib.types.attrs;
              default = [ ];
              description = "ACL rules (each with action, src, dst)";
            };
          };
        };

        tailscale = {
          enable = lib.mkEnableOption "Tailscale VPN client (connects to Headscale)";

          controlPlane = lib.mkOption {
            type = lib.types.enum [ "tailscale" "headscale-local" "headscale-remote" ];
            default = "tailscale";
            description = ''
              Which coordination server this node joins.

              Previously this was inferred: an empty `loginServer` meant
              "Tailscale SaaS" UNLESS headscale happened to be enabled on the
              same machine, in which case it silently meant "auto-join the local
              headscale". That conflated two unrelated facts — whether this host
              RUNS a control server, and which one it JOINS — so a machine
              hosting headscale could not join any other tailnet.

              - "tailscale"         Tailscale Inc.'s coordination server.
              - "headscale-local"   The headscale running on THIS machine.
                                    Requires my.network.headscale.enable.
              - "headscale-remote"  A headscale elsewhere; set loginServer.
            '';
          };

          loginServer = lib.mkOption {
            type = lib.types.str;
            default = "";
            example = "http://<onion>.onion:8090";
            description = ''
              Coordination server URL. Only used when
              controlPlane = "headscale-remote".
            '';
          };

          authKeyFile = lib.mkOption {
            type = lib.types.nullOr lib.types.path;
            default = null;
            description = ''
              File containing the credential used to register this node
              unattended. Two kinds are accepted:

              - a pre-auth key (`tskey-auth-…`), which expires after at most
                90 days and therefore has to be reissued; or
              - an OAuth client secret (`tskey-client-…`), which does NOT
                expire. Prefer this: there is nothing to refresh.

              OAuth-registered nodes are not owned by a user, so Tailscale
              REQUIRES them to be tagged — set `tags` below, or registration
              fails.

              See https://tailscale.com/kb/1215/oauth-clients
            '';
          };

          authKeyParameters = lib.mkOption {
            type = lib.types.submodule {
              options = {
                ephemeral = lib.mkOption {
                  type = lib.types.nullOr lib.types.bool;
                  default = null;
                  description = "Register as an ephemeral node (removed when offline).";
                };
                preauthorized = lib.mkOption {
                  type = lib.types.nullOr lib.types.bool;
                  default = null;
                  description = "Skip manual device approval. Usually wanted for unattended joins.";
                };
                baseURL = lib.mkOption {
                  type = lib.types.nullOr lib.types.str;
                  default = null;
                  description = "Base URL for the Tailscale API.";
                };
              };
            };
            default = { };
            description = ''
              Parameters appended to the auth key as a query string, which is
              how OAuth client secrets carry their registration options.
            '';
          };

          tags = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [ ];
            example = [ "tag:server" ];
            description = ''
              ACL tags to advertise (`--advertise-tags`).

              Required when registering with an OAuth client secret. Also
              useful on their own: tagged nodes do not have their node key
              expire, so a tagged server never silently drops off the tailnet.
            '';
          };

          port = lib.mkOption {
            type = lib.types.port;
            default = 41641;
            description = ''
              UDP port tailscaled binds for WireGuard and peer-to-peer traffic.
              0 means let the kernel pick a free one.

              NOT AN ADDRESS. A tailnet node is reached by its 100.x address or
              its MagicDNS name; this port is only the WireGuard endpoint, and
              peers discover it through the control plane. Nothing in a config,
              a `connect` list or a URL ever names it.

              IT MUST STILL BE UNIQUE PER TAILSCALED ON ONE MACHINE, which only
              becomes true once a host runs container roles: each role is its
              own tailnet node with its own tailscaled, and rootless podman
              NATs through the host, preserving source ports where it can.
              Three nodes all on 41641 means the first to claim it works and the
              rest do not -- reporting `magicsock: network down` and
              `UDP: false` while looking entirely healthy, with `active`, zero
              restarts and an intact registration. The only clue is one line in
              a different container: `Couldn't open flow specific socket:
              Address already in use`. Which node loses is decided by boot
              order, so it moves.

              Roles therefore default to 0 (see platforms/oci.nix) rather than
              being assigned numbers by hand: there is nothing to coordinate and
              nothing to remember.
            '';
          };

          relayServerPort = lib.mkOption {
            type = lib.types.nullOr lib.types.port;
            default = null;
            example = 41647;
            description = ''
              Make this node a PEER RELAY on the given UDP port. Null leaves it
              a plain client.

              A peer relay is tried BEFORE falling back to a DERP server, so a
              machine that hosts container roles can relay for them locally. It
              is worth having because rootless podman NATs each role through the
              host with no reachable UDP endpoint, so roles cannot form direct
              connections -- two containers on ONE machine were measured
              relaying through a DERP server in Denver at ~25ms round trip.

              SETTING THIS IS NOT SUFFICIENT ON ITS OWN. Clients also need a
              grant carrying `tailscale.com/cap/relay` naming this node as the
              destination, and that lives in the TAILNET POLICY, which is not
              NixOS configuration while the fleet uses Tailscale SaaS. Without
              the grant the relay binds its port, advertises nothing usable, and
              every peer quietly stays on DERP -- which looks exactly like the
              feature not working.

              That split is temporary rather than inherent. `my.network.headscale`
              already declares acl.groups, acl.tagOwners and acl.rules, so a
              fleet on a self-hosted control plane keeps its policy in the same
              configuration as everything else -- reviewable, versioned, and
              reproduced by a rebuild. On Tailscale SaaS the policy is state in
              a web console that no rebuild can reproduce, which is the real
              argument for moving, more than any latency it would buy.
            '';
          };

          exitNode = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = "Advertise this node as an exit node";
          };

          advertiseRoutes = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [ ];
            description = "Subnet routes to advertise";
          };

          useRoutingFeatures = lib.mkOption {
            type = lib.types.enum [ "none" "client" "server" "both" ];
            default = "none";
            description = "Enable routing features (client, server, both, or none)";
          };

          ssh = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = ''
              Run the Tailscale SSH server: inbound ssh over the tailnet is
              authenticated by tailnet identity and the tailnet policy's `ssh`
              rules instead of authorized_keys, so clients without local key
              material (a phone, a machine with no security token) can log in.

              Enforced with `tailscale set --ssh=true` rather than an `up`
              flag: `tailscale up` RESETS every preference not named on its
              command line, so a later hand-run `up` would silently switch the
              SSH server off. `tailscale set` changes only what it names.

              The classic sshd keeps running unchanged; tailscaled intercepts
              port 22 on the tailscale interface only.
            '';
          };

          allowedTCPPorts = lib.mkOption {
            type = lib.types.listOf lib.types.port;
            default = [ ];
            description = "TCP ports to allow through firewall on the tailscale interface";
          };

          liveness = {
            enable = lib.mkEnableOption ''
              a periodic probe that this node still has a working PATH onto the
              tailnet, rather than merely a running tailscaled.

              Those are different facts and nothing else here tells them apart.
              When the datapath underneath tailscaled dies -- a crashed
              rootless-podman network helper is the case this was written for --
              the process stays up, its unit stays `active`, `systemctl
              --failed` stays empty, and the node is simply gone. The probe
              closes that by proving a ROUND TRIP to peers it names, so
              "reachable" is measured instead of assumed
            '';

            peers = lib.mkOption {
              type = lib.types.listOf lib.types.str;
              default = [ ];
              example = [ "radicle-yoga-seed" "yoga" ];
              description = ''
                Tailnet nodes to round-trip against, by hostname or MagicDNS
                name.

                Each is resolved OUT OF THIS NODE'S OWN NETMAP, never through
                DNS. That is not a preference: inside a container
                /etc/resolv.conf points at the rootless network helper's
                forwarder, which is one of the things whose death this probe
                exists to catch, so a probe that needed DNS to name its target
                would fail to run on exactly the failure it is for.

                THE LIST IS NOT A SET OF EQUIVALENT ALTERNATIVES, and the
                number of entries changes what a failure means:

                  * no peer answers   -- this node is off the tailnet. A
                                         restart can fix that, so on a role it
                                         escalates (see the oci platform).
                  * some answer, some -- this node is ON the tailnet and one
                    do not              named peer is unreachable. A restart
                                        cannot fix someone else's outage, so
                                        this only fails the unit.
                  * all answer        -- healthy.

                With ONE entry those first two collapse into each other: the
                peer's own downtime restarts this node. A second, more
                reliably-up peer is what separates them, so list the peer whose
                reachability is the POINT first -- for a radicle builder, the
                seed it fetches from -- and a broadly-reachable one after it.
              '';
            };

            startDelay = lib.mkOption {
              type = lib.types.str;
              default = "3min";
              description = ''
                How long after boot the first probe runs. Long enough that
                tailscaled has started, registered and built a netmap, because
                a verdict taken before that is a verdict about boot order.
              '';
            };

            interval = lib.mkOption {
              type = lib.types.str;
              default = "1min";
              description = ''
                How long after a probe FINISHES the next one starts
                (`OnUnitInactiveSec`, never `OnUnitActiveSec` -- see the timer).
              '';
            };

            retries = lib.mkOption {
              type = lib.types.ints.positive;
              default = 10;
              description = ''
                Attempts within one probe run. The verdict is the whole run's,
                not any single attempt's: a run escalates only when EVERY
                attempt agreed no peer answered.
              '';
            };

            retryDelay = lib.mkOption {
              type = lib.types.ints.positive;
              default = 60;
              description = ''
                Seconds between attempts. Together with `retries` this is the
                hysteresis, and the default pair puts ~9 minutes of unbroken
                agreement between a silent tailnet and a container exit.

                SIZED TO CLEAR THE TRANSIENT BAND, not to detect fast. The
                round trip goes dark for reasons that fix themselves in seconds
                to low minutes -- a DERP failover, a relay reselection, a host
                uplink still coming up after a reboot, a suspend and resume --
                and the two sides of this are not symmetric: a wrong escalation
                costs a container reboot, so a builder loses ~4 minutes and
                every CI job it had in flight, while detecting a genuine dead
                datapath at 10 minutes instead of 1 costs nothing, because the
                observed outage ran three hours and was never going to clear on
                its own.

                Widen these rather than weakening the predicate if cold DERP
                handshakes turn out to exceed the 5s per-peer ping timeout. The
                unit's start timeout is DERIVED from both, so widening them
                cannot silently collide with it -- which is what made the 90s
                DefaultTimeoutStartSec a ceiling on this pair before.
              '';
            };
          };
        };

        tor = {
          enable = lib.mkEnableOption "Tor hidden service and/or client";

          onionServices = {
            headscale = {
              enable = lib.mkEnableOption "Tor onion service forwarding to Headscale";

              port = lib.mkOption {
                type = lib.types.port;
                default = 8080;
                description = "Virtual port exposed on the .onion address";
              };
            };
          };

          client = {
            enable = lib.mkEnableOption "Tor SOCKS proxy client (for reaching .onion addresses)";

            socksPort = lib.mkOption {
              type = lib.types.port;
              default = 9050;
              description = "Local SOCKS5 proxy port for Tor";
            };
          };
        };

        unifi = {
          enable = lib.mkEnableOption "declarative UniFi controller config (REST API)";

          controller = {
            url = lib.mkOption {
              type = lib.types.str;
              default = "https://10.45.128.1";
              description = "UniFi controller base URL (UniFi OS console). Self-signed certs are accepted by the reconciler.";
            };

            site = lib.mkOption {
              type = lib.types.str;
              default = "default";
              description = "UniFi site name. Single-site UDM deployments use \"default\".";
            };
          };

          apiKeySecret = lib.mkOption {
            type = lib.types.str;
            default = "unifi/api-key";
            description = ''
              Name of the sops secret (key in secrets.yaml) holding the
              UniFi controller API key. The decrypted file should contain
              the bare key string — no JSON, no quotes. Created in the UDM
              UI under My Account → Control Plane API → Create API Key.
            '';
          };

          desiredStateSecret = lib.mkOption {
            type = lib.types.str;
            default = "unifi/desired-state";
            description = ''
              Name of the sops secret (key in secrets.yaml) holding the
              desired-state YAML. Network names, subnets, VLAN tags and any
              other topology data are private and live only in this
              encrypted blob — never in the public flake.
            '';
          };

          owner = lib.mkOption {
            type = lib.types.str;
            default = "logger";
            description = "User allowed to read the decrypted secrets and invoke unifi-reconciler.";
          };
        };

        ipv6.privacy = {
          enable = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = ''
              IPv6 privacy extensions (RFC 8981 temporary addresses).
              Generates rotating outbound addresses to limit passive tracking
              by third parties. Defaults are the "Strong" tier (5 min preferred,
              30 min valid, 60s desync). Tighter rotation increases churn and
              risks breaking long-lived connections.
            '';
          };

          preferredLifetime = lib.mkOption {
            type = lib.types.ints.positive;
            default = 120;
            description = ''
              Seconds a temporary IPv6 address is preferred for new outbound
              connections (`net.ipv6.conf.*.temp_prefered_lft`). After this,
              the kernel generates a fresh temp address. Must exceed
              `maxDesyncFactor` plus regen_advance (~3s) or the kernel will
              silently disable temp address generation.
            '';
          };

          validLifetime = lib.mkOption {
            type = lib.types.ints.positive;
            default = 600;
            description = ''
              Seconds a temporary IPv6 address remains usable for in-flight
              connections (`net.ipv6.conf.*.temp_valid_lft`). Should be
              several multiples of `preferredLifetime` to let SSH/long syncs
              wrap up before their address expires.
            '';
          };

          maxDesyncFactor = lib.mkOption {
            type = lib.types.ints.positive;
            default = 30;
            description = ''
              Random offset (0..N seconds) subtracted from `preferredLifetime`
              per host so rotation does not happen in lockstep across a network
              (`net.ipv6.conf.*.max_desync_factor`). Kernel default is 600.
            '';
          };

          addrGenMode = lib.mkOption {
            type = lib.types.enum [ 0 1 2 3 ];
            default = 2;
            description = ''
              SLAAC base address generation mode (`net.ipv6.conf.*.addr_gen_mode`):
              0 = EUI-64 (derived from MAC, privacy-bad),
              1 = none,
              2 = stable-privacy (RFC 7217, hash per network) — modern default,
              3 = random (regenerated on every interface bring-up).
              Outbound traffic uses the rotating temp address regardless of
              this value; this controls the stable address used by listeners
              and as a fallback.
            '';
          };
        };

        monitoring = {
          enable = lib.mkEnableOption "network monitoring stack";

          interface = lib.mkOption {
            type = lib.types.str;
            default = "";
            description = "Primary network interface to monitor. Empty string monitors all interfaces.";
          };

          logPath = lib.mkOption {
            type = lib.types.str;
            default = "/var/log/network-monitor";
            description = "Directory for network monitoring logs";
          };

          linkMonitor = {
            enable = lib.mkEnableOption "link state monitoring (detects cable pulls, new interfaces, MAC changes)";
          };

          addrwatch = {
            enable = lib.mkEnableOption "addrwatch IPv4/IPv6 address monitoring (ARP + NDP, detects rogue devices)";
          };

          pcap = {
            enable = lib.mkEnableOption "rotating packet capture with L2 headers (tcpdump)";

            rotateSeconds = lib.mkOption {
              type = lib.types.int;
              default = 3600;
              description = "Rotate pcap files every N seconds";
            };

            maxFiles = lib.mkOption {
              type = lib.types.int;
              default = 168;
              description = "Maximum number of pcap files to keep (default: 168 = 7 days at hourly rotation)";
            };

            snaplen = lib.mkOption {
              type = lib.types.int;
              default = 0;
              description = "Capture snapshot length in bytes. 0 = full packet.";
            };

            filter = lib.mkOption {
              type = lib.types.str;
              default = "";
              description = "BPF filter expression for packet capture";
            };
          };

          tshark = {
            enable = lib.mkEnableOption "tshark protocol-aware capture (Wireshark CLI)";
          };

          suricata = {
            enable = lib.mkEnableOption "Suricata IDS (signature-based intrusion detection)";
          };

          zeek = {
            enable = lib.mkEnableOption "Zeek passive network analysis (protocol logging, anomaly detection)";
          };

          p0f = {
            enable = lib.mkEnableOption "passive OS fingerprinting (detects device identity changes)";
          };

          aide = {
            enable = lib.mkEnableOption "AIDE file integrity monitoring (host-based intrusion detection)";
          };

          netflow = {
            enable = lib.mkEnableOption "NetFlow traffic analysis (softflowd + ntopng)";

            ntopng = {
              enable = lib.mkEnableOption "ntopng web-based traffic analysis dashboard";
            };
          };

          dns = {
            enable = lib.mkEnableOption "Blocky DNS sinkhole (block malicious/ad domains)";
          };
        };
      };
    };
  };
}
