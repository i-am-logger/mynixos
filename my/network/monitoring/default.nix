{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.my.network.monitoring;

  iface = if cfg.interface != "" then cfg.interface else "any";
  ifaceFlag = if cfg.interface != "" then "-i ${cfg.interface}" else "-i any";
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

    # ARP monitoring (arpwatch)
    # Detects: new devices, MAC/IP changes, flip-flops, rogue devices
    (mkIf (cfg.enable && cfg.arpwatch.enable) {
      environment.systemPackages = [ pkgs.arpwatch ];

      systemd.services.network-arpwatch = {
        description = "ARP/MAC anomaly detector (network defense)";
        wantedBy = [ "multi-user.target" ];
        after = [ "network-online.target" ];
        wants = [ "network-online.target" ];

        serviceConfig = {
          Type = "simple";
          ExecStart = concatStringsSep " " ([
            "${pkgs.arpwatch}/bin/arpwatch"
            "-d" # stay in foreground
            "-f"
            "${cfg.logPath}/arp.dat"
          ] ++ optional (cfg.interface != "") [ "-i" cfg.interface ]);
          Restart = "always";
          RestartSec = 5;

          # Arpwatch needs raw socket access
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
  ];
}
