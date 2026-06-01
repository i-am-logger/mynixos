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

          loginServer = lib.mkOption {
            type = lib.types.str;
            default = "";
            description = "Headscale server URL for login (e.g. http://<onion>.onion:8080). Set after yoga bootstrap.";
          };

          authKeyFile = lib.mkOption {
            type = lib.types.nullOr lib.types.path;
            default = null;
            description = "Path to file containing pre-auth key for automatic registration";
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

          allowedTCPPorts = lib.mkOption {
            type = lib.types.listOf lib.types.port;
            default = [ ];
            description = "TCP ports to allow through firewall on the tailscale interface";
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
            default = 300;
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
            default = 1800;
            description = ''
              Seconds a temporary IPv6 address remains usable for in-flight
              connections (`net.ipv6.conf.*.temp_valid_lft`). Should be
              several multiples of `preferredLifetime` to let SSH/long syncs
              wrap up before their address expires.
            '';
          };

          maxDesyncFactor = lib.mkOption {
            type = lib.types.ints.positive;
            default = 60;
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
