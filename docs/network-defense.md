# Network Defense

Network monitoring stack for passive threat detection and forensic analysis. All tools run as hardened systemd services, produce logs to a unified directory, and integrate with impermanence for persistent storage on tmpfs-root systems.

## Quick Start

```nix
my.network.monitoring = {
  enable = true;
  interface = "eth0";  # or "" for all interfaces

  linkMonitor.enable = true;
  arpwatch.enable = true;
  pcap.enable = true;
  suricata.enable = true;
  zeek.enable = true;
  p0f.enable = true;
};
```

## Global Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `enable` | bool | `false` | Master enable for the entire Network Defense stack |
| `interface` | string | `""` | Network interface to monitor. Empty = all interfaces |
| `logPath` | string | `/var/log/network-monitor` | Unified log directory for all modules |

## Modules

### Link Monitor

Monitors L2 link state changes using `ip monitor link neigh`. Detects cable pulls, new interfaces appearing, MAC address changes, and MTU modifications.

**Enable:** `linkMonitor.enable = true`

**Service:** `network-link-monitor`

**Output:** `${logPath}/link-events.log` - timestamped link/neighbor events

**How it works:** Runs `ip monitor link neigh` in a loop, prepending ISO-8601 timestamps to each event. Requires `CAP_NET_ADMIN` capability.

**Use case:** Detect physical layer tampering - unauthorized cable insertions, interface additions, or MAC address spoofing at the link layer.

---

### ARP Watch

Detects ARP and MAC anomalies using `arpwatch`. Maintains a persistent database of known MAC/IP pairings and alerts on changes.

**Enable:** `arpwatch.enable = true`

**Service:** `network-arpwatch`

**Output:** `${logPath}/arp.dat` (persistent database) + syslog alerts

**How it works:** Runs `arpwatch -d` in foreground mode with a persistent ARP database. Detects new stations, flip-flops (MAC/IP reassignments), and changed Ethernet addresses.

**Use case:** Detect rogue devices joining the network, ARP spoofing/poisoning attacks, and unauthorized device substitution.

---

### Packet Capture (tcpdump)

Full packet capture with L2 Ethernet headers, automatic file rotation, and bounded disk usage.

**Enable:** `pcap.enable = true`

**Service:** `network-pcap`

**Output:** `${logPath}/capture-YYYYMMDD-HHMMSS.pcap` - rotating pcap files

**Options:**

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `pcap.rotateSeconds` | int | `3600` | Rotate capture files every N seconds |
| `pcap.maxFiles` | int | `168` | Maximum files to keep (168 = 7 days at hourly) |
| `pcap.snaplen` | int | `0` | Bytes per packet to capture. 0 = full packet |
| `pcap.filter` | string | `""` | BPF filter expression for selective capture |

**How it works:** Runs `tcpdump -e -n -U` with time-based rotation (`-G`) and file count limits (`-W`). Captures include Ethernet headers (`-e`) with no DNS resolution (`-n`).

**Use case:** Forensic packet analysis, incident reconstruction, and evidence preservation.

---

### Suricata IDS

Signature-based intrusion detection system. Detects known attack patterns, C2 beacons, and protocol anomalies using rule sets.

**Enable:** `suricata.enable = true`

**Service:** Uses NixOS native `services.suricata`

**Output:** `${logPath}/suricata-eve.json` - JSON EVE log format

**Persisted state:** `/var/lib/suricata` (rule database and engine state)

**EVE log types enabled:**
- **alert** - signature-based detections
- **anomaly** - protocol anomaly detections
- **dns** - DNS query/response logging
- **tls** - TLS handshake and certificate logging
- **files** - file extraction metadata
- **flow** - connection flow records

**How it works:** Uses `af-packet` mode for high-performance kernel-level packet access with `cluster_flow` threading. Passively inspects traffic against signature rules and behavioral models.

**Use case:** Detect known exploits, malware C2 communications, implant signatures, and protocol-level anomalies.

---

### Zeek

Passive network analysis framework. Generates structured protocol logs for connection tracking, DNS monitoring, TLS inspection, and anomaly detection.

**Enable:** `zeek.enable = true`

**Service:** `network-zeek`

**Output:** `${logPath}/zeek/` - directory of JSON-formatted protocol logs (conn.log, dns.log, tls.log, etc.)

**How it works:** Runs `zeek -C LogAscii::use_json=T` which passively analyzes traffic, ignoring checksum errors (`-C`), and outputs structured JSON logs. Each protocol gets its own log file.

**Use case:** Protocol-level visibility, connection metadata analysis, encrypted traffic profiling (via TLS certificate logging), and behavioral baselining.

---

### P0F

Passive OS fingerprinting. Identifies operating systems and TCP/IP stack behavior of network-connected devices without sending any traffic.

**Enable:** `p0f.enable = true`

**Service:** `network-p0f`

**Output:** `${logPath}/p0f.log` - timestamped fingerprint matches

**How it works:** Analyzes TCP/IP stack characteristics (window size, TTL, options, etc.) to identify operating systems. Runs completely passively - no packets sent.

**Use case:** Detect unauthorized device substitution (fingerprint changes may indicate an implant swap or compromised host), identify unknown devices on the network, and monitor for OS-level anomalies.

## Service Hardening

All custom systemd services (link-monitor, arpwatch, pcap, zeek, p0f) run with:

- `ProtectSystem = "strict"` - read-only filesystem root
- `ReadWritePaths` limited to `logPath` only
- `ProtectHome = true` - no home directory access
- Automatic restart on failure (5s delay, 10s for Zeek)
- `network-online.target` dependency

Suricata uses the NixOS-native service module with its own hardening.

## Log Directory Structure

```
/var/log/network-monitor/
├── link-events.log             # Link state changes
├── arp.dat                     # ARP watch database
├── capture-YYYYMMDD-*.pcap     # Rotating packet captures
├── suricata-eve.json           # Suricata IDS detections
├── zeek/                       # Zeek protocol logs
│   ├── conn.log
│   ├── dns.log
│   ├── tls.log
│   └── ...
└── p0f.log                     # OS fingerprint data
```

## Impermanence Integration

On systems with `my.storage.impermanence.enable = true`, the Network Defense stack automatically persists:

- `${logPath}` (mode `0750`) - all monitoring logs
- `/var/lib/suricata` - Suricata rule database and state

No additional configuration needed - persistence is handled by the module.

## Design Principles

- **Passive only** - no packets transmitted, no network modification
- **Composable** - enable only the modules you need
- **Bounded storage** - pcap rotation prevents unbounded disk growth
- **Unified logging** - all output in one configurable directory
- **Defense in depth** - each module targets a different threat layer (L2, L3, L4-L7, signatures, behavior)
