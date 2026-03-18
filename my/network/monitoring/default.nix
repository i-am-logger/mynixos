{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.my.network.monitoring;

  iface = if cfg.interface != "" then cfg.interface else "any";
  ifaceFlag = if cfg.interface != "" then "-i ${cfg.interface}" else "-i any";

  addrwatch = pkgs.callPackage ../../../packages/addrwatch { };
in
{
  config = mkMerge [
    # Shared configuration when monitoring is enabled
    (mkIf cfg.enable {
      # Create log directory
      systemd.tmpfiles.rules = [
        "d ${cfg.logPath} 0750 root root -"
      ];

      # Persist logs if impermanence is enabled
      environment.persistence = mkIf config.my.storage.impermanence.enable {
        ${config.my.storage.impermanence.persistPath}.directories = [
          {
            directory = cfg.logPath;
            mode = "0750";
          }
        ];
      };
    })

    # Link state monitoring (ip monitor)
    # Detects: cable pulls, new interfaces, MAC changes, MTU changes
    (mkIf (cfg.enable && cfg.linkMonitor.enable) {
      environment.systemPackages = [ pkgs.iproute2 ];

      systemd.services.network-link-monitor = {
        description = "L2 link state monitor (network defense)";
        wantedBy = [ "multi-user.target" ];
        after = [ "network-online.target" ];
        wants = [ "network-online.target" ];

        serviceConfig = {
          Type = "simple";
          ExecStart = "${pkgs.bash}/bin/bash -c '${pkgs.iproute2}/bin/ip monitor link neigh | while IFS= read -r line; do echo \"$(date -Iseconds) $line\"; done >> ${cfg.logPath}/link-events.log'";
          Restart = "always";
          RestartSec = 5;

          # Hardening
          ProtectSystem = "strict";
          ReadWritePaths = [ cfg.logPath ];
          ProtectHome = true;
          NoNewPrivileges = true;
          CapabilityBoundingSet = [ "CAP_NET_ADMIN" ];
          AmbientCapabilities = [ "CAP_NET_ADMIN" ];
        };
      };
    })

    # addrwatch - IPv4 (ARP) and IPv6 (NDP) address monitoring
    # Modern replacement for arpwatch with dual-stack support
    (mkIf (cfg.enable && cfg.addrwatch.enable) {
      environment.systemPackages = [ addrwatch ];

      systemd.services.network-addrwatch = {
        description = "IPv4/IPv6 address monitor (network defense)";
        wantedBy = [ "multi-user.target" ];
        after = [ "network-online.target" ];
        wants = [ "network-online.target" ];

        serviceConfig = {
          Type = "simple";
          ExecStart = concatStringsSep " " ([
            "${addrwatch}/bin/addrwatch_syslog"
          ] ++ optional (cfg.interface != "") cfg.interface);
          Restart = "always";
          RestartSec = 5;

          ProtectSystem = "strict";
          ReadWritePaths = [ cfg.logPath ];
          ProtectHome = true;
        };
      };
    })

    # Rotating packet capture (tcpdump)
    # Full L2 frame capture with Ethernet headers for forensic analysis
    (mkIf (cfg.enable && cfg.pcap.enable) {
      environment.systemPackages = [ pkgs.tcpdump ];

      systemd.services.network-pcap = {
        description = "Rotating L2 packet capture (network defense)";
        wantedBy = [ "multi-user.target" ];
        after = [ "network-online.target" ];
        wants = [ "network-online.target" ];

        serviceConfig = {
          Type = "simple";
          ExecStart = concatStringsSep " " ([
            "${pkgs.tcpdump}/bin/tcpdump"
            "-e" # L2 Ethernet headers
            "-n" # no DNS resolution (stealth)
            "-U" # packet-buffered output
            "${ifaceFlag}"
            "-s"
            (toString cfg.pcap.snaplen) # snapshot length
            "-G"
            (toString cfg.pcap.rotateSeconds) # rotate interval
            "-W"
            (toString cfg.pcap.maxFiles) # max files
            "-w"
            "${cfg.logPath}/capture-%Y%m%d-%H%M%S.pcap"
            "-Z"
            "root" # don't drop privileges (needed for write access)
          ] ++ optional (cfg.pcap.filter != "") cfg.pcap.filter);
          Restart = "always";
          RestartSec = 5;

          ProtectSystem = "strict";
          ReadWritePaths = [ cfg.logPath ];
          ProtectHome = true;
        };
      };
    })

    # tshark - Protocol-aware packet capture (Wireshark CLI)
    # Deeper protocol dissection than tcpdump
    (mkIf (cfg.enable && cfg.tshark.enable) {
      environment.systemPackages = [ pkgs.wireshark-cli ];
    })

    # Suricata IDS
    # Signature-based detection of known attacks, C2 beacons, implant signatures
    (mkIf (cfg.enable && cfg.suricata.enable) {
      services.suricata = {
        enable = true;
        settings = {
          af-packet = [{
            interface = iface;
            cluster-type = "cluster_flow";
          }];
          outputs = [
            {
              eve-log = {
                enabled = true;
                filetype = "regular";
                filename = "${cfg.logPath}/suricata-eve.json";
                types = [
                  { alert = { }; }
                  { anomaly = { enabled = true; }; }
                  { dns = { }; }
                  { tls = { }; }
                  { files = { }; }
                  { flow = { }; }
                ];
              };
            }
          ];
        };
      };

      environment.persistence = mkIf config.my.storage.impermanence.enable {
        ${config.my.storage.impermanence.persistPath}.directories = [
          "/var/lib/suricata"
        ];
      };
    })

    # Zeek network analysis
    # Passive protocol analysis, connection logging, anomaly detection
    (mkIf (cfg.enable && cfg.zeek.enable) {
      environment.systemPackages = [ pkgs.zeek ];

      systemd.services.network-zeek = {
        description = "Zeek passive network analysis (network defense)";
        wantedBy = [ "multi-user.target" ];
        after = [ "network-online.target" ];
        wants = [ "network-online.target" ];

        preStart = ''
          mkdir -p ${cfg.logPath}/zeek
        '';

        serviceConfig = {
          Type = "simple";
          ExecStart = concatStringsSep " " [
            "${pkgs.zeek}/bin/zeek"
            "${ifaceFlag}"
            "-C" # ignore checksum errors
            "LogAscii::use_json=T"
          ];
          WorkingDirectory = "${cfg.logPath}/zeek";
          Restart = "always";
          RestartSec = 10;

          ProtectSystem = "strict";
          ReadWritePaths = [ cfg.logPath ];
          ProtectHome = true;
        };
      };
    })

    # Passive OS fingerprinting (p0f)
    # Detects device identity changes — a fingerprint change may indicate an implant swap
    (mkIf (cfg.enable && cfg.p0f.enable) {
      environment.systemPackages = [ pkgs.p0f ];

      systemd.services.network-p0f = {
        description = "Passive OS fingerprinting (network defense)";
        wantedBy = [ "multi-user.target" ];
        after = [ "network-online.target" ];
        wants = [ "network-online.target" ];

        serviceConfig = {
          Type = "simple";
          ExecStart = concatStringsSep " " [
            "${pkgs.p0f}/bin/p0f"
            "${ifaceFlag}"
            "-o"
            "${cfg.logPath}/p0f.log"
          ];
          Restart = "always";
          RestartSec = 5;

          ProtectSystem = "strict";
          ReadWritePaths = [ cfg.logPath ];
          ProtectHome = true;
        };
      };
    })

    # AIDE - File integrity monitoring (host-based intrusion detection)
    # Detects unauthorized file modifications, rootkits, backdoors
    (mkIf (cfg.enable && cfg.aide.enable) {
      environment = {
        systemPackages = [ pkgs.aide ];

        # AIDE database and config
        etc."aide.conf".text = ''
          database_in=file:/var/lib/aide/aide.db
          database_out=file:/var/lib/aide/aide.db.new
          database_new=file:/var/lib/aide/aide.db.new

          # What to check
          Binlib = p+i+n+u+g+s+b+m+c+sha256
          ConfFiles = p+i+n+u+g+s+b+m+c+sha256
          Logs = p+i+n+u+g

          # Critical system paths
          /bin Binlib
          /sbin Binlib
          /usr/bin Binlib
          /usr/sbin Binlib
          /etc ConfFiles

          # Exclude volatile paths
          !/etc/mtab
          !/etc/resolv.conf
          !/var
          !/tmp
          !/run
          !/proc
          !/sys
          !/dev
        '';

        persistence = mkIf config.my.storage.impermanence.enable {
          ${config.my.storage.impermanence.persistPath}.directories = [
            { directory = "/var/lib/aide"; mode = "0700"; }
          ];
        };
      };

      systemd = {
        tmpfiles.rules = [
          "d /var/lib/aide 0700 root root -"
        ];

        # Daily integrity check
        services.aide-check = {
          description = "AIDE file integrity check (network defense)";
          serviceConfig = {
            Type = "oneshot";
            ExecStart = "${pkgs.aide}/bin/aide --check --config=/etc/aide.conf";
            StandardOutput = "append:${cfg.logPath}/aide-check.log";
            StandardError = "append:${cfg.logPath}/aide-check.log";
          };
        };

        timers.aide-check = {
          description = "Daily AIDE file integrity check";
          wantedBy = [ "timers.target" ];
          timerConfig = {
            OnCalendar = "daily";
            Persistent = true;
            RandomizedDelaySec = "1h";
          };
        };
      };
    })

    # NetFlow - Traffic flow analysis
    # softflowd exports flow data, ntopng provides web dashboard
    (mkIf (cfg.enable && cfg.netflow.enable) {
      environment.systemPackages = [ pkgs.softflowd ];

      systemd.services.network-softflowd = {
        description = "NetFlow exporter (network defense)";
        wantedBy = [ "multi-user.target" ];
        after = [ "network-online.target" ];
        wants = [ "network-online.target" ];

        serviceConfig = {
          Type = "simple";
          ExecStart = concatStringsSep " " [
            "${pkgs.softflowd}/bin/softflowd"
            "-d" # foreground
            "${ifaceFlag}"
            "-n"
            "localhost:2055" # export to localhost for ntopng
            "-v"
            "9" # NetFlow v9
          ];
          Restart = "always";
          RestartSec = 5;

          ProtectSystem = "strict";
          ProtectHome = true;
        };
      };
    })

    # ntopng - Web-based traffic analysis dashboard
    (mkIf (cfg.enable && cfg.netflow.enable && cfg.netflow.ntopng.enable) {
      services.ntopng = {
        enable = true;
        extraConfig = ''
          --interface=${if cfg.interface != "" then cfg.interface else "any"}
          --local-networks="192.168.0.0/16,10.0.0.0/8,172.16.0.0/12"
          --disable-login=1
        '';
      };

      environment.persistence = mkIf config.my.storage.impermanence.enable {
        ${config.my.storage.impermanence.persistPath}.directories = [
          "/var/lib/ntopng"
        ];
      };
    })

    # Blocky - DNS sinkhole
    # Blocks malicious domains, ads, and C2 at DNS level
    (mkIf (cfg.enable && cfg.dns.enable) {
      services.blocky = {
        enable = true;
        settings = {
          upstreams.groups.default = [
            "https://dns.cloudflare.com/dns-query"
            "https://dns.google/dns-query"
          ];
          blocking = {
            denylists = {
              ads = [
                "https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts"
              ];
              malware = [
                "https://urlhaus.abuse.ch/downloads/hostfile/"
              ];
            };
            clientGroupsBlock.default = [ "ads" "malware" ];
          };
          ports = {
            dns = 5353; # non-standard port to avoid conflicts
            http = 4000; # web UI
          };
          log.level = "info";
        };
      };
    })
  ];
}
