# Network Defense

Comprehensive network monitoring and host-based intrusion detection stack. All tools run as hardened systemd services, produce logs to a unified directory, and integrate with impermanence for persistent storage on tmpfs-root systems.

## Quick Start

```nix
my.network.monitoring = {
  enable = true;
  interface = "eth0";  # or "" for all interfaces

  # Network monitoring
  linkMonitor.enable = true;
  addrwatch.enable = true;
  pcap.enable = true;
  tshark.enable = true;

  # Intrusion detection
  suricata.enable = true;
  zeek.enable = true;
  p0f.enable = true;
  aide.enable = true;

  # Traffic analysis
  netflow = {
    enable = true;
    ntopng.enable = true;
  };

  # DNS sinkhole
  dns.enable = true;
};
```

## Global Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `enable` | bool | `false` | Master enable for the entire stack |
| `interface` | string | `""` | Network interface to monitor. Empty = all interfaces |
| `logPath` | string | `/var/log/network-monitor` | Unified log directory for all modules |

## Modules

### Link Monitor

Monitors L2 link state changes using `ip monitor link neigh`. Detects cable pulls, new interfaces appearing, MAC address changes, and MTU modifications.

**Enable:** `linkMonitor.enable = true`

**Service:** `network-link-monitor`

**Output:** `${logPath}/link-events.log` - timestamped link/neighbor events

**Use case:** Detect physical layer tampering - unauthorized cable insertions, interface additions, or MAC address spoofing at the link layer.

---

### addrwatch

Modern replacement for arpwatch. Monitors both IPv4 (ARP) and IPv6 (NDP) address pairings on the network. Detects new devices, MAC/IP changes, and rogue devices with dual-stack support.

**Enable:** `addrwatch.enable = true`

**Service:** `network-addrwatch`

**Output:** syslog (structured address pairing events)

**Use case:** Detect rogue devices, ARP spoofing, NDP spoofing, and unauthorized device substitution on IPv4 and IPv6 networks.

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

**Use case:** Forensic packet analysis, incident reconstruction, and evidence preservation.

---

### tshark (Wireshark CLI)

Protocol-aware packet capture and dissection. Provides deeper protocol analysis than tcpdump with Wireshark's full dissector library.

**Enable:** `tshark.enable = true`

**Installs:** `wireshark-cli` package (includes tshark, editcap, mergecap, etc.)

**Use case:** Deep protocol inspection, pcap post-processing, and protocol-specific filtering during incident analysis.

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

**Use case:** Detect known exploits, malware C2 communications, implant signatures, and protocol-level anomalies.

---

### Zeek

Passive network analysis framework. Generates structured protocol logs for connection tracking, DNS monitoring, TLS inspection, and anomaly detection.

**Enable:** `zeek.enable = true`

**Service:** `network-zeek`

**Output:** `${logPath}/zeek/` - directory of JSON-formatted protocol logs (conn.log, dns.log, tls.log, etc.)

**Use case:** Protocol-level visibility, connection metadata analysis, encrypted traffic profiling (via TLS certificate logging), and behavioral baselining.

---

### P0F

Passive OS fingerprinting. Identifies operating systems and TCP/IP stack behavior of network-connected devices without sending any traffic.

**Enable:** `p0f.enable = true`

**Service:** `network-p0f`

**Output:** `${logPath}/p0f.log` - timestamped fingerprint matches

**Use case:** Detect unauthorized device substitution, identify unknown devices on the network, and monitor for OS-level anomalies.

---

### AIDE (File Integrity)

Advanced Intrusion Detection Environment. Monitors critical system files for unauthorized modifications — detects rootkits, backdoors, and tampering.

**Enable:** `aide.enable = true`

**Service:** `aide-check` (runs daily via systemd timer)

**Output:** `${logPath}/aide-check.log` - integrity check results

**Monitored paths:**
- `/bin`, `/sbin`, `/usr/bin`, `/usr/sbin` — binary integrity (permissions, inode, SHA-256)
- `/etc` — configuration file integrity

**Excluded paths:** `/var`, `/tmp`, `/run`, `/proc`, `/sys`, `/dev` (volatile)

**Persisted state:** `/var/lib/aide` (AIDE database)

**Use case:** Detect unauthorized file modifications to system binaries and configuration. First line of defense against rootkits and supply chain attacks.

---

### NetFlow (softflowd + ntopng)

Network traffic flow analysis. softflowd exports NetFlow v9 data, ntopng provides a real-time web dashboard for traffic visualization.

**Enable:** `netflow.enable = true` (softflowd) + `netflow.ntopng.enable = true` (web dashboard)

**Services:** `network-softflowd` + NixOS native `services.ntopng`

**ntopng dashboard:** `http://localhost:3000` (login disabled by default)

**Persisted state:** `/var/lib/ntopng`

**Use case:** Traffic flow analysis, bandwidth anomaly detection, top talkers identification, and network capacity planning.

---

### Blocky DNS Sinkhole

DNS-level blocking of malicious domains, ads, and C2 infrastructure. Uses DNS-over-HTTPS upstream for encrypted resolution.

**Enable:** `dns.enable = true`

**Service:** NixOS native `services.blocky`

**Ports:** DNS on `5353`, Web UI on `4000`

**Block lists:**
- **ads** — StevenBlack unified hosts (ads + malware + fakenews)
- **malware** — URLhaus malicious URL blocklist

**Upstream DNS:** Cloudflare DoH + Google DoH

**Use case:** Block known malicious domains, C2 callbacks, ad networks, and tracking domains at the DNS layer before connections are established.

## Service Hardening

All custom systemd services run with:

- `ProtectSystem = "strict"` - read-only filesystem root
- `ReadWritePaths` limited to `logPath` only
- `ProtectHome = true` - no home directory access
- Automatic restart on failure (5s delay, 10s for Zeek)
- `network-online.target` dependency

Suricata, ntopng, and Blocky use NixOS-native service modules with their own hardening.

## Log Directory Structure

```
/var/log/network-monitor/
├── link-events.log             # Link state changes
├── capture-YYYYMMDD-*.pcap     # Rotating packet captures
├── suricata-eve.json           # Suricata IDS detections
├── zeek/                       # Zeek protocol logs
│   ├── conn.log
│   ├── dns.log
│   ├── tls.log
│   └── ...
├── p0f.log                     # OS fingerprint data
└── aide-check.log              # AIDE integrity check results
```

## Impermanence Integration

On systems with `my.storage.impermanence.enable = true`, the stack automatically persists:

- `${logPath}` (mode `0750`) - all monitoring logs
- `/var/lib/suricata` - Suricata rule database and state
- `/var/lib/aide` - AIDE integrity database
- `/var/lib/ntopng` - ntopng traffic data

## Design Principles

- **Passive only** - no packets transmitted, no network modification (except DNS sinkhole)
- **Composable** - enable only the modules you need
- **Bounded storage** - pcap rotation prevents unbounded disk growth
- **Unified logging** - all output in one configurable directory
- **Defense in depth** - each module targets a different threat layer (L2, L3, L4-L7, signatures, behavior, file integrity, DNS)
- **Dual-stack** - addrwatch monitors both IPv4 and IPv6
