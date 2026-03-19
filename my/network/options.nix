{ lib, ... }:

{
  network = lib.mkOption {
    description = "Network configuration (mesh VPN, Tor, monitoring)";
    default = { };
    type = lib.types.submodule {
      options = {
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
