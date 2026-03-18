{ lib, ... }:

{
  network = lib.mkOption {
    description = "Network defense configuration (passive monitoring and threat detection)";
    default = { };
    type = lib.types.submodule {
      options = {
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
