# RKE2 + Cilium on this fleet: the configuration reference

Status: **not built.** This file is the third of three and the last one before Nix gets written.
`docs/k8s-fleet-constraints.md` says what any distribution must satisfy here; `docs/k8s-fleet-decision.md`
says which one was chosen and what the choice costs. This file says **what every knob is set to, and why** —
so that the module, when it is written, is a transcription rather than a design.

The rule this file is written under: **every knob carries what it is, the value we set, why, and a
`file:line` citation.** A knob with no citation is not in this file. Where the evidence disagreed with itself,
or could not be checked at the version this fleet will actually run, that is said in the text rather than
smoothed over — `docs/k8s-fleet-constraints.md` has a "not established" tradition and this file keeps it.

Citations resolve against three trees:

| Prefix | Tree |
|---|---|
| `my/…`, `tests/…`, `docs/…`, `platforms/…` | this repo |
| `rke2/…`, `rke2-charts/…`, `k3s/…`, `cilium/…` | the research clones under `/tmp/rke2-fleet-research/` |
| `nixos/…`, `pkgs/…` | the pinned nixpkgs, `/nix/store/c4ymw711a6r51sgvazgk9kvy1r6cxqhy-source` |

The pinned nixpkgs was resolved with
`nix eval --raw --impure --expr 'let f = builtins.getFlake (toString ./.); in f.inputs.nixpkgs.outPath'`,
per **C90** — not by picking a source tree out of the store, which already produced a two-minor error in this
project's own constraint about version skew.

## The pins, and how they were checked

| Thing | Value | Where it comes from |
|---|---|---|
| RKE2 | **1.35.7+rke2r1** | `pkgs/applications/networking/cluster/rke2/1_35/versions.nix:2` |
| nixpkgs attribute | **`rke2_1_35`**, named explicitly | `pkgs/applications/networking/cluster/rke2/default.nix:12` |
| CNI | **cilium** | `nixos/modules/services/cluster/rancher/rke2.nix:84-105` |
| Cilium chart | **`rke2-cilium` 1.19.601** | `rke2/charts/chart_versions.yaml:2` |
| Cilium | **v1.19.6** | the chart version's first four digits; corroborated below |
| Datastore | **embedded etcd** | `rke2/pkg/cli/defaults/defaults.go:24` sets `ClusterInit = true` |
| Kubernetes | v1.35.7 | `pkgs/applications/networking/cluster/rke2/1_35/versions.nix:6` |

**Pin the package attribute, never `pkgs.rke2`.** `rke2 = rke2_stable`
(`pkgs/top-level/all-packages.nix:9111`) and `rke2_stable = rke2_1_35`
(`pkgs/applications/networking/cluster/rke2/default.nix:17`) — a moving alias, and the file says so in a
comment at `:16`: "Automatically set by update script". skyspy-dev is away for months at a time and rebuilds
against whatever the alias has become; an agent ahead of its server does not join. Both hosts read
`services.rke2.package = pkgs.rke2_1_35` from one shared place (**C86**).

Note a citation drift worth recording: an earlier reading of **C86** took the alias line number from a
*different* nixpkgs tree in the store. In the pinned tree the alias is at
`pkgs/top-level/all-packages.nix:9111`, and that is the citation to use. The constraint itself is unaffected —
the alias is exactly where C86 says it is, in the file it says — but a line number carried over from an
arbitrary `/nix/store/*-source` is how a document acquires a citation that looks right and resolves to
nothing. The citation gate catches precisely this, which is why the stale number is described here rather
than reproduced.

### The Cilium version, settled

`docs/k8s-fleet-decision.md:563` records this as unresolved: one agent read `rke2-cilium` **1.19.601** in the
rke2 clone, another read a **1.20.1** base in the rke2-charts monorepo, and the decision record could not
say which the fleet would run. It is now settled, both ways:

- The rke2 clone's working tree pins `rke2-cilium 1.19.601` (`rke2/charts/chart_versions.yaml:2`).
- The clone carries the tag `v1.35.7+rke2r1` — **the exact version the pinned nixpkgs builds**. Reading
  `charts/chart_versions.yaml` at that tag gives `1.19.601` as well.

So `1.19.601` is what ships, and the chart's base version is Cilium **v1.19.6**. The rke2-charts figure of
1.20.1 (`rke2-charts/packages/rke2-cilium/package.yaml:1`) is the monorepo's *current build input*, which
says nothing about what a released RKE2 carries. Both agents were right about the tree they read.

### Version risk on every Cilium citation

The cilium clone's working tree is `main` — its `VERSION` file reads `1.21.0-dev`, and
`git rev-list --count HEAD` is 1. **This fleet runs v1.19.6.** The clone does, however, carry the `v1.19.6`
tag, so for this file **every Cilium claim below was re-read at `v1.19.6`** and the result is stated. The
citation given is the on-disk (`main`) path and line, because that is what resolves as a file; where the
v1.19.6 line differs it is given in parentheses.

Verified identical or near-identical at v1.19.6:

| Claim | `main` citation | at v1.19.6 |
|---|---|---|
| `TunnelOverheadIPv4 = 50` | `cilium/pkg/mtu/mtu.go:30` | line 30, identical |
| `Calculate` / `getRouteMTU` / `getDeviceMTU` | `cilium/pkg/mtu/mtu.go:113`, `:127`, `:167` | lines 113, 127, 167, identical |
| configured-MTU short circuit | `cilium/pkg/mtu/cell.go:150` | line 151 |
| endpoint-updater chaining gate | `cilium/pkg/mtu/endpoint_updater.go:70-81` | lines 70-81, identical |
| `min(dev.MTU)` over selected devices | `cilium/pkg/mtu/manager.go:55` | line 57 |
| device name constants | `cilium/pkg/defaults/node.go:21`, `:24`, `:36`, `:69-75` | identical |
| VXLAN port 8472 | `cilium/pkg/defaults/defaults.go:471` | line 475 |
| cluster health port 4240 | `cilium/pkg/defaults/defaults.go:24` | line 24, identical |
| `tcp_mtu_probing` written per pod netns | `cilium/plugins/cilium-cni/cmd/cmd.go:1419` | line 1388 |

`values.yaml` line numbers move more, because `main` has grown content; each is given with its v1.19.6
counterpart where it is cited.

**One correction this re-reading produces.** `docs/k8s-fleet-constraints.md:1120` downgrades **C67**'s
PLPMTUD leg to "unconfirmed at 1.19.6" because the clone was shallow. It is now confirmed, and it is
confirmed in a more useful shape than C67 claimed:

- `pmtuDiscovery.enabled` is **`false`** at v1.19.6 (`cilium/install/kubernetes/cilium/values.yaml:546`,
  v1.19.6 line 541). That is the feature which sends ICMP fragmentation-needed replies, and it is off.
- `pmtuDiscovery.packetizationLayerPMTUDMode: "blackhole"` is the default
  (`cilium/install/kubernetes/cilium/values.yaml:550`, v1.19.6 line 546) and it is rendered into the
  ConfigMap **unconditionally**, outside the `enabled` guard
  (`cilium/install/kubernetes/cilium/templates/cilium-configmap.yaml:1358`, v1.19.6 line 1301).
- `blackhole` maps to the integer `1` (`cilium/pkg/mtu/cell.go:103`) and cilium-cni writes it to
  `net.ipv4.tcp_mtu_probing` in every pod network namespace
  (`cilium/plugins/cilium-cni/cmd/cmd.go:1419`, v1.19.6 line 1388).

So RFC 4821 PLPMTUD **is** active in pod netns at v1.19.6, and C67's rescue leg stands — but it was
mis-attributed twice over: it is upstream Cilium's default, not RKE2's chart, and it comes from a value that
is *not* gated by the `pmtuDiscovery` switch. It rescues TCP only; UDP and QUIC get nothing. That is why the
MTU assertion in the VM test must read the pod's route MTU as a number rather than infer health from a large
payload arriving (**C18**, **C67 revised**).

## Ports

RKE2's server ports are fixed in its own defaults, not derived from anything:

```
ServerConfig.AdvertisePort   = 6443     rke2/pkg/cli/defaults/defaults.go:27
ServerConfig.SupervisorPort  = 9345     rke2/pkg/cli/defaults/defaults.go:28
ServerConfig.HTTPSPort       = 6443     rke2/pkg/cli/defaults/defaults.go:29
ServerConfig.APIServerPort   = 6443     rke2/pkg/cli/defaults/defaults.go:30
APIServerBindAddress         = 0.0.0.0  rke2/pkg/cli/defaults/defaults.go:31
```

**9345 is the one people forget.** It is the *supervisor* — the registration endpoint an agent dials to
bootstrap, before it has any kubeconfig. It is separate from 6443 and it is also where RKE2 serves packaged
charts on server nodes, which is why the nixpkgs module records it as `staticContentPort = 9345`
(`nixos/modules/services/cluster/rancher/rke2.nix:32`). An agent that can reach 6443 but not 9345 never
joins, and the failure looks like an authentication problem.

### The full list

| Port | Proto | Listener | Dialled by | Opened on |
|---|---|---|---|---|
| **9345** | TCP | server (supervisor + static charts) | agents | `tailscale0` |
| **6443** | TCP | server (kube-apiserver) | agents, clients | `tailscale0` |
| **10250** | TCP | kubelet, every node | server (metrics-server, `kubectl logs`/`exec`) | `tailscale0` |
| **4240** | TCP | cilium-agent (cluster health) | peer cilium-agents | `tailscale0` |
| **8472** | UDP | cilium VXLAN tunnel | peer nodes | `tailscale0` |
| **4244** | TCP | Hubble server, every node | hubble-relay | `tailscale0` |
| 2379 / 2380 | TCP | etcd client / peer | nothing — one member | **nowhere** |
| 4245 | TCP | hubble-relay | `hubble` CLI, Hubble UI | **nowhere** — ClusterIP |
| 9962 / 9965 / 9966 | TCP | agent / Hubble / relay metrics | Prometheus, if any | **nowhere** this run |
| 10256 / 10257 / 10259 | TCP | kube-proxy / controller-manager / scheduler | localhost probes | **nowhere** |

Citations, in the order the rows appear:

- 10250 is the kubelet's port; RKE2 inherits it from Kubernetes rather than declaring it, and the clones
  record it in the upstream preflight list (`k3s/contrib/util/check-config.sh:277`, which enumerates
  `6443 10250 5001 2379 2380`).
- 4240 — `cilium/pkg/defaults/defaults.go:24` (`ClusterHealthPort = 4240`), identical at v1.19.6.
- 8472 — `cilium/pkg/defaults/defaults.go:471` (`TunnelPortVXLAN uint16 = 8472`), v1.19.6 line 475. The chart
  leaves `tunnelPort: 0` and lets the default stand (`cilium/install/kubernetes/cilium/values.yaml:3244`,
  v1.19.6 line 3067); the comment above it names 8472 for VXLAN and 6081 for Geneve. VXLAN is the default
  tunnel protocol (`values.yaml:3227` is `tunnelProtocol: ""` with `@default -- "vxlan"`; v1.19.6 line 3051)
  in the default tunnel routing mode (`values.yaml:3241`, `@default -- "tunnel"`; v1.19.6 line 3064).
- 4244 — `cilium/install/kubernetes/cilium/values.yaml:1671` (`listenAddress: ":4244"`) and `:1688`
  (`peerService.targetPort: 4244`); v1.19.6 lines 1618 and 1634. The Hubble server runs inside the
  cilium-agent DaemonSet, which is host-networked, so this is a **host** port that relay dials across nodes.
- 2379 / 2380 — `k3s/pkg/etcd/etcd.go:983` and `:967`. Both bind the node address, but with a single etcd
  member there is no peer to dial 2380 and no external client on 2379, so neither is opened. **If a second
  server is ever added, both become tailnet ports** and this row changes.
- 4245 — `cilium/install/kubernetes/cilium/values.yaml:1881` (`listenPort: "4245"`), v1.19.6 line 1807.
  hubble-relay is a `ClusterIP` service (`cilium/install/kubernetes/cilium/values.yaml:1875`), so it is
  reached over the pod network, not the host. `hubble observe` from a workstation goes through
  `kubectl port-forward` or a `tailscale serve` against the ClusterIP — the same idiom the forge already uses
  for :443.
- 9962 / 9965 / 9966 — `values.yaml:2695` (agent Prometheus), `:1504` (Hubble metrics server), and the relay
  metrics port RKE2 turns *on* in its fork
  (`rke2-charts/packages/rke2-cilium/generated-changes/patch/values.yaml.patch:86-87`, flipping
  `hubble.relay.prometheus.enabled` to `true` on port 9966). No Prometheus exists on this fleet yet, so none
  of the three is opened; they are listed so that adding one is a firewall line and not a rediscovery.
- 10256 / 10257 / 10259 — `rke2/pkg/podtemplate/spec.go:196`, `:138`, `:108`. Control-plane component health
  and metrics ports, on the node itself.

### Where they are opened, and where they must not be

**Scoped to `tailscale0`, never fleet-wide.** The idiom the repo already has:

```nix
networking.firewall.interfaces.tailscale0.allowedTCPPorts = [ 6443 9345 10250 4240 4244 ];
networking.firewall.interfaces.tailscale0.allowedUDPPorts = [ 8472 ];
```

`my/network/tailscale/default.nix:98` is the existing writer of the TCP form, and
`my/network/openssh/default.nix:65-66` is the existing example of a *feature module* contributing its own
port by writing the plain NixOS option directly. The cluster domain follows openssh rather than routing
through `my.network.tailscale.allowedTCPPorts`: the comment at `my/network/openssh/default.nix:54-63`
explains that `my.network` is one submodule option, so reading any leaf of it merges every definition of the
whole thing — a hazard for a module that also gates on something under `my.network`. The cluster domain gates
on `my.infra`, so it would not actually recurse; writing the plain option anyway keeps one rule for
"a feature contributes its own port" instead of two.

**The current module gets this wrong in exactly the way that matters.** `my/infra/k3s/default.nix:38-41`
writes `networking.firewall.allowedTCPPorts = [ cfg.apiPort ]` — every interface. On skyspy-dev, a laptop
that attaches to café wifi, that offers the Kubernetes API to the café (**C21**, **C46**).

**The nixpkgs module opens nothing.** Neither `rancher/default.nix` nor `rancher/rke2.nix` touches
`networking.firewall`; the only `firewall` strings in the whole directory are the unit's `after`/`wants` on
`firewall.service` (`nixos/modules/services/cluster/rancher/default.nix:910`, `:914`) and a doc line in
`k3s.nix:55` telling the reader to go and configure it. Ports are entirely the consumer's job.

**`trustedInterfaces` follows the CNI, and under Cilium it is not `cni0`/`flannel.1`.**
`my/infra/k3s/default.nix:40` hardcodes flannel's names; under Cilium those interfaces never appear and the
real ones are untrusted, which drops pod traffic at the host firewall with nothing naming the cause
(**C22**). The Cilium names are constants:

```
cilium_host    cilium/pkg/defaults/node.go:21
cilium_net     cilium/pkg/defaults/node.go:24
cilium_vxlan   cilium/pkg/defaults/node.go:36
lxc*           cilium/pkg/defaults/node.go:72   (the endpoint veth prefix)
```

all identical at v1.19.6. `networking.firewall.trustedInterfaces` is `listOf str`
(`nixos/modules/services/networking/firewall.nix:164-173`) and each entry is interpolated straight into
`ip46tables -A nixos-fw -i ${iface}` (`nixos/modules/services/networking/firewall-iptables.nix:150`), so
iptables' `+` wildcard is representable: `"lxc+"`, not `"lxc*"`. A shell glob there would match nothing and
fail silently.

### What does not collide, and the one thing that does

**RKE2's own ports are free on yoga.** 6443 and 9345 are unused there today (**C83**). The only conflict is
RKE2's default ingress: `rke2-ingress-nginx` is patched from a Deployment into a **DaemonSet**
(`rke2-charts/packages/rke2-ingress-nginx/generated-changes/patch/values.yaml.patch:74`) with
`hostPort.enabled: true` (`:56`) and `dnsPolicy: ClusterFirstWithHostNet` (`:47`), so it claims 80 and 443 on
every node it lands on. `tailscale serve` holds :443 on yoga's tailnet address for the Radicle explorer.
Whichever binds first wins, and if nginx wins the explorer stops answering with nothing logging a conflict.
The answer is under **Hardening**: `disable = [ "rke2-ingress-nginx" ]`.

## CNI configuration

RKE2 deploys the CNI as a packaged Helm chart, and the supported way to change a packaged chart's values is a
`HelmChartConfig` object dropped into the server's manifests directory. `services.rke2.manifests` renders an
attrset and links it there. This is the *whole* configuration mechanism for the CNI — there is no flag, and
nixpkgs' own RKE2 test says so in a comment: "For K3s this can be handled via `--flannel-iface`, but RKE2's
canal has to be configured with this manifest"
(`nixos/tests/rancher/multi-node.nix:110-114`, with the working `HelmChartConfig` at `:115-126`).

### The manifest

```nix
services.rke2.manifests.rke2-cilium-config.content = {
  apiVersion = "helm.cattle.io/v1";
  kind = "HelmChartConfig";
  metadata = {
    name = "rke2-cilium";
    namespace = "kube-system";
  };
  # spec.valuesContent is a STRING, either JSON or YAML.
  spec.valuesContent = builtins.toJSON {
    # The device MTU. Yields a pod route MTU of 1230 -- see "MTU" below.
    MTU = 1280;

    hubble = {
      # RKE2's fork ships Hubble OFF. This is the reason this CNI was chosen,
      # so turning it on is not optional.
      enabled = true;
      relay.enabled = true;
      ui.enabled = true;
      metrics.enabled = [ "dns" "drop" "tcp" "flow" "port-distribution" "icmp" "http" ];
    };

    # Cilium's init container writes /etc/sysctl.d/99-zzz-override_cilium.conf
    # and restarts systemd-sysctl. On a tmpfs root that is ephemeral by
    # construction, but it is a host mutation with a NixOS-shaped alternative:
    # declare the same keys in boot.kernel.sysctl and turn the writer off.
    sysctlfix.enabled = false;
  };
};
```

**Do not name the attribute `*.yaml`.** RKE2 opens `.yaml`/`.yml` manifests `O_RDWR`, which a read-only store
path cannot serve, so the nixpkgs module sets `jsonManifests = true` for RKE2
(`nixos/modules/services/cluster/rancher/rke2.nix:24-27`) and the target suffix is derived from the attribute
name (`nixos/modules/services/cluster/rancher/default.nix:34-41`): a name already ending `.yaml` is passed
through and will break; anything else gets `.json`. `rke2-cilium-config` becomes
`rke2-cilium-config.json`, which is right.

**`spec.valuesContent` really is a string.** The submodule renders `content` to a file; the *inner* values
must be a JSON or YAML string, which is what `builtins.toJSON` is doing. This is the shape nixpkgs' own test
uses (`nixos/tests/rancher/multi-node.nix:122-125`).

### What RKE2's fork already overrides, and what we add

Upstream defaults are cited at their on-disk (`main`) line with the v1.19.6 line in parentheses; the fork's
overrides are cited into the values patch, which at the rke2-charts clone's HEAD is generated against Cilium
**1.20.1**, not 1.19.6 — see the caveat below the table.

| Value | Upstream v1.19.6 | RKE2's fork | We set | Why |
|---|---|---|---|---|
| `cni.chainingMode` | `~` (`values.yaml:789`, v1.19.6 782) | **`portmap`** (`patch:25`) | — | The fork's comment: "Otherwise rke2 hostPort does not work! Used for nginx". This is what disables the endpoint-MTU updater — see **MTU**. |
| `cni.exclusive` | `true` (`values.yaml:803`, v1.19.6 796) | **`false`** (`patch:41`) | — | The fork disables it so Multus can work. Cilium therefore does *not* rename other CNI configs in `/etc/cni/net.d`. |
| `hubble.enabled` | `true` (`values.yaml:1453`, v1.19.6 1397) | **`false`** (`patch:63`) | **`true`** | **C69.** Hubble is the reason this CNI was chosen and the fork ships it off. Cilium alone buys no observability until this lands. |
| `hubble.relay.enabled` | `false` (`values.yaml:1768`, v1.19.6 1696) | — | **`true`** | The Hubble server is per-node; relay is what aggregates it into one `hubble observe`. Without relay, Hubble is a per-node socket. |
| `hubble.ui.enabled` | `false` (`values.yaml:2016`, v1.19.6 1939) | — | **`true`** | The service map, which is one of the six things Hubble has that Calico's Whisker does not (`docs/k8s-fleet-decision.md:189-194`). Fronted with `tailscale serve`, per **Ports**. |
| `hubble.metrics.enabled` | `~` (`values.yaml`, the `metrics` block at `:1504` carries `port: 9965`; v1.19.6 1440) | — | an explicit list | `~` means no metrics server at all. The list is what turns per-flow data into Prometheus series; the port is already 9965. |
| `hubble.relay.prometheus.enabled` | `false` | **`true`**, port 9966 (`patch:86-87`) | — | The fork already turns this on. Recorded so nobody sets it twice. |
| `ipam.mode` | `cluster-pool` (`values.yaml:2326`, v1.19.6 2227) | **`kubernetes`** (`patch:121`) | — | Node PodCIDRs come from the Kubernetes node object rather than Cilium's own pool. This is why there is no `clusterPoolIPv4PodCIDRList` to set. |
| `kubeProxyReplacement` | `"false"` (`values.yaml:2470`, v1.19.6 2366) | not set (`patch` never mentions it) | **not set** | **C68.** Upstream's `false` stands and RKE2 keeps its own kube-proxy. Enabling KPR is what would attach BPF programs at the cgroup2 root above every process on yoga, including the rootless-podman forge. Hubble needs none of it. |
| `envoy.enabled` | `~` (`@default -- true` for new installs) | **`false`** (`patch:134`) | — | No standalone Envoy DaemonSet. L7 policy would need it; L7 policy is not in scope. |
| `operator.setNodeTaints` | `~` | **`false`** (`patch:187`) | — | Nodes are not tainted while Cilium is coming up. Relevant to bring-up ordering, not to a value we set. |
| `MTU` | `0` (`values.yaml:3262`, v1.19.6 3085) | not set | **`1280`** | The whole of the next section. |
| `sysctlfix.enabled` | `true` (`values.yaml:4369`, v1.19.6 4157) | not set | **`false`** | The init container `nsenter`s PID 1's mount namespace to run `cilium-sysctlfix` on the host (`cilium/install/kubernetes/cilium/templates/cilium-agent/daemonset.yaml:637`, v1.19.6 line 617). Turning it off and declaring the same keys in `boot.kernel.sysctl` moves a host mutation into the configuration that owns host mutations. |
| encryption (`encryption.enabled`) | `false` | not set | **not set** | Frozen spec: the tailnet already WireGuards this traffic, and a second layer costs 60 more bytes of the same 1280 budget (**C19**), taking the pod route MTU to 1170 for confidentiality that already exists. |
| `cluster-cidr` / `service-cidr` | `10.42.0.0/16` / `10.43.0.0/16` (`k3s/pkg/cli/cmds/server.go:139`, `:144`) | — | **not set** | **C25** requires no overlap with `100.64.0.0/10`, the range Tailscale allocates node addresses from. The defaults already satisfy it, so setting them would be a knob with no purpose and a second thing to keep right. |

**The patch caveat.** `rke2-charts/packages/rke2-cilium/generated-changes/patch/values.yaml.patch` in the
clone is generated against `https://helm.cilium.io/cilium-1.20.1.tgz`
(`rke2-charts/packages/rke2-cilium/package.yaml:1`), and the clone is one commit deep with no history for
that path, so **the 1.19.601-era patch cannot be read from the evidence on disk.** What the table's "RKE2's
fork" column therefore establishes is *which values Rancher overrides and in which direction* — a stable
property of the fork across versions — and not that the 1.19.601 chart's patch has these exact line numbers.
`hubble.enabled: false` is independently corroborated by **C69**, which the constraints doc marks VERIFIED.
The others are marked as unverified-at-1.19.601 in the return summary.

### One host mutation that happens regardless

Independent of `sysctlfix` and of `kubeProxyReplacement`, an init container `nsenter`s PID 1's cgroup and
mount namespaces to mount a second cgroup2 filesystem at `/run/cilium/cgroupv2`
(`cilium/install/kubernetes/cilium/templates/cilium-agent/daemonset.yaml` — the `mount-cgroup` container,
v1.19.6 lines 544-571). On a tmpfs root it is ephemeral by construction. It is recorded because it is the
kind of thing that gets discovered during an incident rather than before one.

### Cilium keeps no persistent node state here

**C63** asks that a CNI which keeps node-local state declare it from the same persistence expression, gated
on that CNI being selected. For Cilium, in this configuration, the term is **empty**, and that is a finding
rather than an omission: the agent's runtime directory is `/var/run/cilium`
(`cilium/pkg/defaults/defaults.go:54`) with its state directory beneath it (`:63`) — a tmpfs runtime path
that is discarded and rebuilt every start on every host, impermanent or not. The one thing that *would* be
identity is a per-node encryption key, and encryption is off.

## MTU

Two numbers, and confusing them costs 50 bytes.

- **The knob reads 1280.** That is the *device* MTU — what Cilium puts on `cilium_host`, `cilium_net` and
  `cilium_vxlan`, which is exactly what the values file's own comment says the key does
  (`cilium/install/kubernetes/cilium/values.yaml:3258-3262`, v1.19.6 3081-3085).
- **The pod route MTU it yields is 1230.** That is the number a test asserts (**C18**, **C66**).

### The arithmetic

With `MTU: 1280` the configured-MTU branch runs and calls `Calculate(1280)`
(`cilium/pkg/mtu/cell.go:162-168`, v1.19.6 163-168):

```
Calculate(baseMTU)                          cilium/pkg/mtu/mtu.go:113-119
  DeviceMTU = getDeviceMTU(1280) = 1280     cilium/pkg/mtu/mtu.go:167-173
  RouteMTU  = getRouteMTU(1280)             cilium/pkg/mtu/mtu.go:127-164
              = baseMTU - (tunnelOverhead + encryptOverhead)      :155
              = 1280 - (50 + 0)
              = 1230
```

`tunnelOverhead` is `TunnelOverheadIPv4 = 50` (`cilium/pkg/mtu/mtu.go:30`), selected because the underlay is
IPv4 (`cilium/pkg/mtu/mtu.go:99-103`), and the constant's own comment breaks it down: outer IP 20, outer UDP
8, outer VXLAN 8, original Ethernet 14 (`cilium/pkg/mtu/mtu.go:20-31`). `encryptOverhead` is 0 because
neither IPsec nor WireGuard is enabled (`cilium/pkg/mtu/mtu.go:139-145`). All line numbers identical at
v1.19.6.

**Set the knob to 1230 and you get 1180.** `getRouteMTU` subtracts the tunnel overhead from whatever you
configure; it does not know that you already did. This is **C66** and it is the single easiest thing in this
document to get backwards.

**1280 is a floor, not a coincidence.** It is the fixed TUN MTU of `tailscale0` — observed live and recorded
at `docs/k8s-fleet-constraints.md:106-114` — and it is also the IPv6 minimum MTU. Single-stack IPv4 was
chosen, so the IPv6 floor does not bite here, but it is why the route MTU cannot be pushed lower through this
knob without leaving supported territory.

Setting the value at all is what makes the ConfigMap carry an `mtu` key: the template emits it only when the
value is truthy (`cilium/install/kubernetes/cilium/templates/cilium-configmap.yaml:612-614`, v1.19.6
576-578), and `0` is the default (`cilium/pkg/mtu/cell.go:77`).

### Why it is pinned rather than auto-detected

**Not because autodetection computes the wrong answer.** **C16** originally said pod MTU must never be
auto-detected, because every auto-MTU implementation probes the interface carrying the default route and on
these hosts that is a 1500-byte NIC. For Cilium that is false: the MTU manager takes `min(dev.MTU)` over its
selected devices (`cilium/pkg/mtu/manager.go:55`, v1.19.6 57) and `tailscale0` is a selected device — it is
not in `ExcludedDevicePrefixes` (`cilium/pkg/defaults/node.go:69-75`, identical at v1.19.6) and it was
verified live on yoga to have a global route. Left alone, Cilium converges on 1280 by itself. **C65**
supersedes C16's framing, and **C89** records that the mechanism was first overturned on the wrong citation.

**The reason to pin is that the self-heal does not exist here.** RKE2's fork sets
`cni.chainingMode: portmap`, and Cilium refuses to register the endpoint-MTU updater when the chaining mode
is anything but `"none"` unless the CNI config or the agent config explicitly asks it to manage route MTU in
chaining mode:

```go
if p.CNI.GetChainingMode() != "none" {                      cilium/pkg/mtu/endpoint_updater.go:71
    ...
    if !EnableRouteMTU && !p.MTUConfig.EnableRouteMTUForCNIChaining {
        return &endpointUpdater                              cilium/pkg/mtu/endpoint_updater.go:78-80
    }
}
p.JobGroup.Add(job.OneShot("endpoint-mtu-updater", ...))     cilium/pkg/mtu/endpoint_updater.go:85
```

identical at v1.19.6, and `EnableRouteMTUForCNIChaining` defaults to `false`
(`cilium/pkg/mtu/cell.go:76`). So the MTU manager can recompute all it likes and **nothing propagates the
result to running pods.** The pods that would miss an update are exactly the boot-time system pods — CoreDNS,
metrics-server — created before any device settles.

A pinned value sidesteps the whole path: with a non-zero configured MTU the manager is never started at all
(`cilium/pkg/mtu/cell.go:150-183`, v1.19.6 151-183), the route MTU is computed once and written into the
statedb table, and every node on this fleet gets the same number regardless of what NICs it happens to have.
That is the argument — **determinism across three differently-shaped machines, compensating for a missing
self-heal** — and not "autodetection is wrong".

**Do not reach for `cni.enableRouteMTUForCNIChaining` as a workaround.** It exists
(`cilium/pkg/mtu/cell.go:82`) and it would re-enable the updater, but it was read here at `main` and its
interaction with `portmap` chaining at v1.19.6 has not been tested on this fleet. Pinning the value costs one
line and needs no such test.

### What a wrong value actually does

Not a silent hang. **C67** refuted **C20** for this stack: Cilium sets neither `DF` on `cilium_vxlan` nor
`BPF_F_DONT_FRAGMENT`, so an oversized outer packet is IP-fragmented by the local kernel, carried by
Tailscale and reassembled at the peer — and, as re-verified above, `net.ipv4.tcp_mtu_probing = 1` is written
into every pod netns, so TCP recovers through RFC 4821 without ICMP. The symptom is **throughput collapse,
reassembly pressure and loss amplification**, and UDP and QUIC get no rescue.

The consequence for the test suite is concrete: **a VM test that only asks "did a large payload arrive"
passes on a misconfigured cluster**, because fragmentation makes it arrive. Assert the pod's route MTU as the
number 1230, directly (**C18**, **C58**).

## Join credential

### The token

**`tokenFile`, never `token`.** The file-valued option renders `--token-file <path>` into the unit
(`nixos/modules/services/cluster/rancher/default.nix:936`); the string-valued one renders `--token <value>`
(`:935`), and the unit is a store path, so a `token = "…"` publishes the cluster's join secret to a
world-readable, permanent, `nix copy`-able location by a route the sops assertions cannot see — they check
`sops.secrets.<name>.sopsFile`, not arbitrary strings (**C29**). The nixpkgs option's own description says
so: "**WARNING**: This option will expose your token unencrypted in the world-readable nix store"
(`nixos/modules/services/cluster/rancher/default.nix:434-435`).

```nix
sops.secrets.rke2-token = { mode = "0400"; };          # owner defaults to root
services.rke2.tokenFile = config.sops.secrets.rke2-token.path;
```

- `mode = "0400"`, root-owned, is the repo's existing idiom for key material — the remote-builder ssh key
  (`my/dev/remote-builders/default.nix:33-35`) and the radicle node key
  (`my/infra/radicle/default.nix:137-139`), both with the same reasoning: systemd reads credential sources as
  root before any `User=` drops privileges (**C30**).
- The sops file it comes from must be a **runtime path**, never a store path.
  `my.secrets.allowSecretsInStore` defaults to `false` (`my/secrets/options.nix:19-21`) and the policy
  asserts on both the fleet default and every per-secret `sopsFile` override
  (`my/secrets/default.nix:65-73`, `:74-82`) — two assertions, because the per-secret override bypasses
  `my.secrets` entirely and is the easier one to add without thinking (**C26**, **C27**).
- The shape the policy exists to block is indirect: `"${someFlakeInput}/secrets.yaml"` reads as one file and
  copies the whole directory it sits in (`my/secrets/options.nix:32-36`) — which is how a seed's plaintext
  node key ended up world-readable on this fleet already (**C28**).
- **Let RKE2 generate the token, then store it** (**C102**). It is the whole restore story: every etcd
  snapshot's bootstrap blob holds every CA private key, encrypted under a key derived from the token.
  Snapshot without token is an unopenable file; token without snapshot is just a fresh cluster.
- `agentToken` / `agentTokenFile` are not set. On a server they would split the join secret in two for no
  benefit at this size; on an agent the module warns that they should not be set at all
  (`nixos/modules/services/cluster/rancher/default.nix:834-836`).

**skyspy-dev has no `my.secrets` block at all** (**C32**), and no dedicated `/persist` partition. Wiring sops
there is a prerequisite of it joining, not a step in this configuration.

### `tls-san` — the one thing that cannot be fixed by rebuilding

**There is no nixpkgs option.** The complete `services.rke2` surface is `agentToken`, `agentTokenFile`,
`autoDeployCharts`, `charts`, `configPath`, `containerdConfigTemplate`, `disable`, `environmentFile`,
`extraFlags`, `extraKubeletConfig`, `extraKubeProxyConfig`, `gracefulNodeShutdown`, `images`, `manifests`,
`nodeExternalIP`, `nodeIP`, `nodeLabel`, `nodeName`, `nodeTaint`, `package`, `role`, `selinux`, `serverAddr`,
`token`, `tokenFile` (`nixos/modules/services/cluster/rancher/default.nix:408-806`) plus rke2's own `cni` and
`cisHardening` (`nixos/modules/services/cluster/rancher/rke2.nix:84`, `:107`). **No `tlsSan`** (**C78**).

It goes through `extraFlags` — type `either str (listOf str)`
(`nixos/modules/services/cluster/rancher/default.nix:467-475`), flattened onto the command line at `:950` —
or through `configPath` (`:485-489`, rendered as `--config` at `:939`). The underlying flag is `--tls-san`
(`k3s/pkg/cli/cmds/server.go:237`).

```nix
services.rke2.extraFlags = [
  "--tls-san=yoga.tail46cce1.ts.net"
  "--tls-san=yoga"
  "--tls-san=100.97.96.49"
];
```

(The tailnet name and yoga's address are the ones recorded live at
`docs/k8s-fleet-constraints.md:24` and `:167-170`; a consumer flake supplies its own.)

**Every name a peer might use, decided before the cluster first starts.** The server's serving certificate is
generated once and persisted; a name that is not in the SAN list at that moment cannot be added by changing
the configuration and rebuilding — it takes imperative surgery against persisted state. Include the MagicDNS
name (what agents and `kubectl` from aether5d-dev will dial, **C23**), the short hostname, and the tailnet IP
(what `serverAddr` will literally be, **C82**). Adding one later costs exactly the same surgery as forgetting
all of them, so there is no reason to be economical here.

Note `--tls-san-security` defaults to true (`k3s/pkg/cli/cmds/server.go:241-246`, the `Value: true` at
`:245`): the server refuses SANs that are not associated with the apiserver service, server nodes, or values
of `tls-san`. That is the mechanism that makes forgetting a name a hard failure rather than a warning.

### Address and identity are different things

**C82** resolves the tension between **C23** (peers address each other by MagicDNS name) and the fact that
`tailscaled`'s resolver is not up when rke2 starts:

```nix
services.rke2 = {
  role       = "agent";
  serverAddr = "https://100.97.96.49:9345";   # a literal tailnet IP: no resolver needed
  nodeName   = "skyspy-dev";                  # identity is a name
  nodeIP     = "100.x.y.z";                   # this node's own tailnet address, explicit
};
```

- `serverAddr` is `str`, defaulting to `""` (`nixos/modules/services/cluster/rancher/default.nix:422-427`),
  rendered as `--server` at `:934`. Its example in the module is a bare IP with a port, which is the shape
  used here. **Port 9345, not 6443** — an agent bootstraps through the supervisor.
- `nodeIP` is `nullOr str` (`:515-519`), rendered as `--node-ip=` at `:944`. Without it the kubelet's
  interface choice falls to the default route, which on yoga is a LAN address no off-site node can reach
  (**C24**).
- `nodeName` (`:497-501`, rendered at `:941`) is the name the cluster and every human sees.

**Order the unit after `tailscaled`.** The shared rancher unit orders only on `firewall.service` and
`network-online.target` (`nixos/modules/services/cluster/rancher/default.nix:909-916`), and neither implies a
tailnet address. Four things are computed in that window — `--node-ip`, the apiserver advertise address,
kubelet registration and the agent's `serverAddr` — so this is one fix for four symptoms (**C65**). The
repo already has the idiom: `my/network/tailscale/default.nix:228-229` orders a unit
`after`/`wants` `tailscaled.service`. Add an `ExecStartPre` that blocks until the node's `100.64.0.0/10`
address is present, because unit ordering and address availability are different readiness conditions.

## State directories

yoga's root is a 16 GB tmpfs and `/persist` is a dedicated partition mounted `neededForBoot`
(`my/storage/impermanence/impermanence.nix:36-38`). Anything not named is gone at every reboot. The base
system list is only `/etc/nixos`, `/var/lib/nixos`, `/var/lib/systemd` and `/var/log`
(`my/storage/impermanence/impermanence.nix:102-107`); everything else is contributed by feature modules
through `my.system.persistence.features.systemDirectories` (`:109`), which is `unique`d at `:102` precisely so
that two features can both be right about needing the same path (**C34**).

**Today `/var/lib/rancher` is persisted by nothing.** The only declaration anywhere in the repo is in the
GitHub-runner module (`my/infra/github-runner/default.nix:496`), which is off on both hosts. Without the
expression below, the datastore *and the cluster CA* land on the tmpfs root, and RKE2 then sets
`clusterReset = true` on every boot because `server/db/etcd/name` is missing
(`rke2/pkg/rke2/rke2_linux.go:89-91`) — a new cluster wearing the old hostname, every reboot (**C97**).

### The expression

One contribution point, terms gated per role, following the forge (`my/infra/radicle/default.nix:399-402`)
— which is the shape **C59** names:

```nix
my.system.persistence.features.systemDirectories =
  [
    # Node identity: the password the server checks at every re-registration.
    "/etc/rancher/node"
    # Kubelet client cert, pods/ volume mounts, device-plugin sockets.
    "/var/lib/kubelet"
    # The containerd content store. On a tmpfs root, every image pulled after a
    # reboot is resident RAM competing with the 28 GB /tmp on the same machine.
    "/var/lib/rancher/rke2/agent/containerd"
    # The rke2-runtime image, re-extracted at every start of both roles.
    "/var/lib/rancher/rke2/data"
  ]
  ++ optionals (cfg.role == "server") [
    # The datastore AND the authoritative copy of the cluster CA. Persist the
    # whole of db/, never db/etcd alone.
    "/var/lib/rancher/rke2/server/db"
    # Reconciled from db/ at every start; persisted so a restart is a restart.
    "/var/lib/rancher/rke2/server/cred"
    "/var/lib/rancher/rke2/server/tls"
  ];
```

An agent has no datastore, no cluster CA and no node token, so everything server-only sits behind the
`optionals` (**C60**). A directory is persisted **iff** the thing that owns it is enabled; an unconditional
flat list persists directories for services that are off, and an empty persisted directory is
indistinguishable from a service that failed to write (**C59**).

### PERSIST, with what each holds

| Path | Holds | Citation |
|---|---|---|
| `/etc/rancher/node` | `password` (mode 0600), created if absent and read thereafter; `id` only under `--with-node-id` | `k3s/pkg/agent/config/config.go:486` (the directory), `:492` (the file), `:217` (the mode), `:509` (`id`) |
| `/var/lib/kubelet` | kubelet client cert, `pods/` volume mounts, plugin sockets | `rke2/pkg/executor/staticpod/staticpod.go:147` shows RKE2 using it (`--volume-plugin-dir=/var/lib/kubelet/volumeplugins`); the loss analysis is `docs/k8s-fleet-constraints.md:238` |
| `/var/lib/rancher/rke2/agent/containerd` | image content and snapshots | `k3s/pkg/agent/config/config.go:568` (`Containerd.Root`) |
| `/var/lib/rancher/rke2/data` | the extracted rke2-runtime image; `…/rke2/bin` is symlinked at it | `rke2/pkg/bootstrap/bootstrap.go:52-58`, `:79-80`; self-pruning at `:120-122` |
| `/var/lib/rancher/rke2/server/db` | etcd data, snapshots, and the bootstrap blob the CA is reconciled from | `k3s/pkg/etcd/etcd.go:255` (`db/etcd`), `k3s/pkg/etcd/snapshot.go:73` (`db/snapshots`) |
| `/var/lib/rancher/rke2/server/cred`, `…/server/tls` | server credentials and certificates | `k3s/pkg/cluster/bootstrap_test.go:84-85` names both paths |

**`/var/lib/kubelet` carries a caveat.** It is in the constraints doc's Persistence table
(`docs/k8s-fleet-constraints.md:238`) with a clear rationale, but **C80** and **C92** — which are the
verified, surgical rewrites of that table — neither confirm nor remove it. It is carried here because losing
it means a fresh CSR every boot and silent data loss on any `hostPath` volume, and because nothing in C80 or
C92 argues against it. It is flagged rather than asserted.

**`server/db` whole, never `db/etcd` alone.** A missing `db/etcd/name` sets `clusterReset = true` on every
boot (`rke2/pkg/rke2/rke2_linux.go:89-91`) — an RKE2-specific failure worse than the generic loss the table
describes. The datastore choice adds nothing to this list either way: etcd lives at `db/etcd/`
(`k3s/pkg/etcd/etcd.go:255`) and kine at `db/state.db` (`:264`), both inside `db/` (**C94**).

### NEVER-PERSIST, and why it is not squeamishness

`services.rke2.manifests`, `images` and `charts` are rendered as **systemd-tmpfiles `L+` symlinks into
`/nix/store`**:

```
manifestDir           = /var/lib/rancher/rke2/server/manifests
imageDir              = /var/lib/rancher/rke2/agent/images
containerdConfigTmpl  = /var/lib/rancher/rke2/agent/etc/containerd/config.toml.tmpl
staticContentChartDir = /var/lib/rancher/rke2/server/static/charts
```

declared in order at `nixos/modules/services/cluster/rancher/default.nix:27`, `:28`, `:29` and `:30`, with
the rules themselves at `nixos/modules/services/cluster/rancher/default.nix:849` (manifests), `:856`
(images), `:871` (charts) and `:879` (the containerd template). **`L+` creates or replaces a symlink; it
never prunes one whose declaration has gone away.** Persist the parent and every manifest ever declared
leaves a link in `/persist` pointing at a store path that will eventually be garbage-collected — and RKE2's
deploy controller keeps trying to apply it. A manifest renamed six months ago is still being reconciled, from
a dangling link, with nothing naming the cause (**C80**).

| Path | Why never |
|---|---|
| `…/server/manifests` | `L+` into the store; a rebuild's deletions become ineffective |
| `…/agent/images` | same |
| `…/server/static/charts` | same |
| `…/agent/etc` | holds `containerd/config.toml.tmpl`, itself an `L+` symlink (`nixos/modules/services/cluster/rancher/default.nix:29`, `:877-880`) |
| `…/agent/pod-manifests` | control-plane static pods, rewritten from config at every server start (`rke2/pkg/executor/staticpod/spw.go:47-49`). A persisted stale one is a control-plane pod the kubelet keeps running that the current config no longer describes — **it survives the rebuild meant to remove it** (**C92**) |
| `…/server` (the parent) | accumulates `tls-<unixtime>` cluster-reset backups that are never pruned (**C92**) |
| `/etc/rancher` (the parent) | `rke2.yaml`, `rke2-pss.yaml` and `audit-policy.yaml` are rewritten every start, and persisting the parent drags the **admin kubeconfig** into `/persist`, which the next section exists to prevent (**C81**, refuted-and-corrected) |
| `…/agent/*.crt`, `*.key`, `*.kubeconfig` | re-requested from the server and overwritten unconditionally at every start; not identity (**C91**) |

### Persist both halves or neither

The node password lives in `/etc/rancher/node` and everything else in `/var/lib/rancher/rke2`. Three
outcomes, two of them stable (**C81**):

| Persisted | Result |
|---|---|
| both | correct — the node rejoins as itself |
| neither | self-heals — it re-registers cleanly as a new-but-identical node |
| one of the two | **broken every boot** — the server remembers a password the node no longer has |

The failure is `Node password rejected, duplicate hostname or contents of '<file>' may not match server
node-passwd entry` (`k3s/pkg/agent/config/config.go:180`), it happens at *re-registration* rather than at
boot, and it looks like a network problem. yoga is server-and-agent, so it validates its own node password
locally — a single-node cluster breaks on this too, not just a joining agent.

**The VM test must reboot a node and assert it rejoins with the same identity.** It is the only assertion
that distinguishes the three rows.

### Two things this expression does not do

- It does **not** go into a host file's `extraSystemDirectories`. A host must not have to know which
  directories a cluster needs (**C33**).
- It must be right on **both** Linux hosts even though only yoga wipes. skyspy-dev enables
  `my.storage.impermanence` over a plain ext4 that nothing wipes, so a missing declaration is invisible there
  and fatal on yoga (**C36**).

And one that moves in the same milestone: `my/infra/github-runner/default.nix:496` currently declares
`/var/lib/rancher`, `/var/lib/kubelet` and `/var/lib/cni` as an unconditional flat list for a cluster it does
not own. It is **replaced by** the expression above rather than relocated, because it is both incomplete and
undifferentiated (**C62**).

## Images and architecture

RKE2 can be pre-provisioned with its container images so that first start does not depend on docker.io.
`services.rke2.images` takes a list of derivations (`nixos/modules/services/cluster/rancher/default.nix:648-666`)
and links each into `imageDir` as a tmpfiles `L+` rule (`:853-858`), where the agent imports them.

The package exposes them as **arch-suffixed passthru attributes**, one per component per architecture, built
by mapping `fetchurl` over `images-versions.json` (`pkgs/applications/networking/cluster/rke2/builder.nix:154`):

```
images-core-linux-amd64-tar-zst      pkgs/applications/networking/cluster/rke2/1_35/images-versions.json:54
images-core-linux-arm64-tar-zst      pkgs/applications/networking/cluster/rke2/1_35/images-versions.json:62
images-cilium-linux-amd64-tar-zst    pkgs/applications/networking/cluster/rke2/1_35/images-versions.json:38
images-cilium-linux-arm64-tar-zst    pkgs/applications/networking/cluster/rke2/1_35/images-versions.json:46
```

The URLs are pinned to the release tag `v1.35.7+rke2r1` and hashed, which satisfies **C50** — no unpinned
remote fetch during activation.

### The selection must be a function of the platform, not a constant

**C40**: a module that names one of those attributes literally produces a system that cannot be built for the
other architecture, and the error arrives as a missing attribute at eval time on the *second* host, not on
the first. nixpkgs' own RKE2 test already has the idiom
(`nixos/tests/rancher/default.nix:56-68`): an attrset keyed by `pkgs.stdenv.hostPlatform.system`, indexed
with `or (throw "…: Unsupported system: …")`, so an unsupported platform fails with a sentence rather than
with `attribute 'x' missing`.

```nix
services.rke2.images =
  {
    x86_64-linux = with cfg.package; [
      images-core-linux-amd64-tar-zst
      images-cilium-linux-amd64-tar-zst
    ];
    aarch64-linux = with cfg.package; [
      images-core-linux-arm64-tar-zst
      images-cilium-linux-arm64-tar-zst
    ];
  }
  .${pkgs.stdenv.hostPlatform.system}
    or (throw "my.infra.<cluster>: unsupported system ${pkgs.stdenv.hostPlatform.system}");
```

The architecture is read from the platform, which a host already states once through its hardware profile;
asking for it again as a cluster option would be two sources for one fact, and they will disagree (**C42**).

### Single-arch this run, and what changes when it is not

aether5d-dev is client-only for this run, so **the cluster is single-arch `x86_64` and C38–C41 are
forward-looking rather than live** (`docs/k8s-fleet-constraints.md:475-479`). The expression above is
written for both anyway, because the cost is four lines now and a rewrite later.

What changes when the aarch64 Linux VM node lands:

- **Every workload image must exist for both `linux/amd64` and `linux/arm64`** — as a manifest list, or as
  per-arch tags behind a node selector. A single-arch workload must be pinned to matching nodes explicitly
  (**C38**).
- **The failure is at pod start, not at evaluation.** Nix type-checks nothing about an image reference;
  `nix flake check` passes, both closures build, and the failure is `exec format error` or an
  `ImagePullBackOff` weeks later. A gate that intends to catch this must inspect manifests (**C39**).
- **There is no fast native `aarch64-linux` build path on this fleet.** yoga can build it only through qemu
  binfmt, gated behind the developer feature; aether5d-dev is an `aarch64-**darwin**` builder and provides no
  `aarch64-linux` at all (**C41**). Whatever provisions the VM must say where its closure is built.

**One thing not established.** Whether RKE2's `rke2-images-cilium` tarball contains the **hubble-relay** and
**hubble-ui** images is not checkable from the evidence on disk — the airgap set is a `fetchurl` of a
release tarball, and the only in-clone signal is that Rancher mirrors both under `rancher/mirrored-cilium-*`
(`rke2-charts/packages/rke2-cilium/generated-changes/patch/values.yaml.patch:72`, `:95`, `:108`). If they are
absent, the two Hubble pods pull from a registry at first start; that is a bring-up observation, not a
blocker, and it is worth one `crictl images` check on the day.

## Hardening

### The four sysctls, and why this is the highest-hurt item in the analysis

`services.rke2.enable = true` writes four kernel sysctls **machine-wide, for every host that enables RKE2**,
whether or not CIS hardening was asked for:

```nix
config = lib.mkIf cfg.enable (          # nixos/modules/services/cluster/rancher/rke2.nix:123
  ...
  boot.kernel.sysctl = {                # nixos/modules/services/cluster/rancher/rke2.nix:144
    "vm.panic_on_oom" = 0;              #   :145
    "vm.overcommit_memory" = 1;         #   :146
    "kernel.panic" = 10;                #   :147
    "kernel.panic_on_oops" = 1;         #   :148
  };
  users = lib.mkIf cfg.cisHardening {   # nixos/modules/services/cluster/rancher/rke2.nix:151
```

The comment above the block says "CIS hardening" (`nixos/modules/services/cluster/rancher/rke2.nix:141-143`)
and the guard covers only the `users` block beneath it.

yoga is a daily-driver Hyprland desktop running amdgpu, whose root is a 16 GB tmpfs.
`kernel.panic_on_oops = 1` turns any kernel oops into a panic and `kernel.panic = 10` reboots ten seconds
later — **and a reboot discards the root filesystem.** A GPU oops that today degrades a session would instead
wipe the root, on the one machine whose `my/forensics/` exists to investigate exactly such events. The blast
radius is the workstation, not the cluster (**C76**).

**`mkForce` each key, per key, never the attrset wholesale.** These are plain values, not `mkDefault`, so any
other definition is a conflict rather than a merge — `mkForce` is required, not preferred. Per-key because a
future nixpkgs bump that adds a fifth key must surface as a visible change rather than be silently swallowed:

```nix
boot.kernel.sysctl = {
  "kernel.panic"          = lib.mkForce 0;
  "kernel.panic_on_oops"  = lib.mkForce 0;
  "vm.panic_on_oom"       = lib.mkForce 0;
  "vm.overcommit_memory"  = lib.mkForce 0;
};
```

**Assert the resulting values in the VM test** (**C77**). The guardrail is for a bug class — "an upstream
module reaches outside its own domain" — not for one instance of it.

`vm.panic_on_oom = 0` and `vm.overcommit_memory` are listed for completeness of the override; the two that
change behaviour dangerously here are `kernel.panic` and `kernel.panic_on_oops`.

### Ingress: give :443 back to the forge

```nix
services.rke2.disable = [ "rke2-ingress-nginx" ];
```

`disable` is `listOf str`, rendered as one `--disable=` per entry
(`nixos/modules/services/cluster/rancher/default.nix:491-495`, `:940`); RKE2's own description points at the
packaged-components documentation (`nixos/modules/services/cluster/rancher/rke2.nix:55-57`). The chart is
patched into a hostNetwork-shaped **DaemonSet** claiming 80 and 443 on every node it lands on
(`rke2-charts/packages/rke2-ingress-nginx/generated-changes/patch/values.yaml.patch:74` for
`kind: DaemonSet`, `:56` for `hostPort.enabled: true`, `:47` for `dnsPolicy: ClusterFirstWithHostNet`), and
`tailscale serve` already holds :443 on yoga's tailnet address for the Radicle explorer. Whichever binds
first wins, and if nginx wins the explorer stops answering with nothing logging a conflict (**C83**).

Cluster services are fronted with `tailscale serve` against their ClusterIPs instead — which is also the
answer to "how does anything get exposed", and it keeps one owner for :443.

### NetworkManager: one owner for `unmanaged-devices`

The nixpkgs rke2 module writes its own `NetworkManager/conf.d/rke2-canal.conf` setting `unmanaged-devices`
(`nixos/modules/services/cluster/rancher/rke2.nix:133-139`), guarded only on
`config.networking.networkmanager.enable` — which mynixos sets `mkDefault true` on every Linux system
(`my/system/core/default.nix:229`). mynixos already writes that key at
`my/system/core/default.nix:159-162`, and its list carries the `podman*`, `docker*` and `br-*` entries that
keep NetworkManager's hands off the **running** Radicle forge. NetworkManager reads `conf.d` in lexical order
and a later file wins for the same key; `'9'` is 0x39 and `'r'` is 0x72, so **`rke2-canal.conf` sorts last
and wins**, silently dropping the podman and bridge exclusions. NetworkManager then runs DHCP on `podman*`
and can take the interface down under a running container. **The failure will look like a Radicle problem**
(**C64**).

```nix
environment.etc."NetworkManager/conf.d/rke2-canal.conf".enable = lib.mkForce false;
```

`mkForce` because the upstream value is a plain expression, not a `mkDefault`
(`nixos/modules/services/cluster/rancher/rke2.nix:134`).

`my/system/core/default.nix:159` stays the single owner and is extended with Cilium's interface names —
`cilium_host`, `cilium_net`, `cilium_vxlan`, `lxc*` (`cilium/pkg/defaults/node.go:21`, `:24`, `:36`, `:72`).
Ownership deliberately does *not* move into the cluster domain: core's list protects a workload that has
nothing to do with Kubernetes, and a forge outage caused by a cluster module rewriting a shared key is
exactly the coupling this exists to prevent (**C74**). The two duplicate writers —
`my/infra/k3s/default.nix:31-34` and `my/infra/github-runner/default.nix:329` — are removed in the same
milestone.

### systemd-oomd: decide it, do not discover it

`my/system/core/default.nix:134-138` sets `oomd.enableRootSlice = true` unconditionally — not `mkDefault`.
`kubepods.slice` is a direct child of the cgroup root, so **every pod is an oomd kill candidate from day
one** on a machine whose root is a 16 GB tmpfs competing with a 28 GB `/tmp`. A SIGKILLed `cilium-agent` is a
whole-node network outage, it will read as a Cilium bug, and every hour spent debugging Cilium will be wasted
(**C85**).

Two shapes, and the decision belongs in the bring-up milestone:

- `lib.mkForce false` on `enableRootSlice` — a mynixos change with fleet-wide effect, backing out a setting
  that was deliberate;
- or `ManagedOOMPreference = "avoid"` on `kubepods.slice`, which scopes the exception to the cluster and
  leaves the root slice policy alone.

**The second is the recommendation**: it is the narrower change, it names the thing being protected, and it
does not weaken oomd for the desktop workloads it was turned on for. Not deciding is itself a decision, and
it is the wrong one.

### Cluster DNS must not share a failure domain with the dataplane

yoga's `/etc/resolv.conf` points at MagicDNS, `100.100.100.100`. That is a valid global-unicast address, so
**the kubelet's loopback-resolver detection does not fire** and every pod inherits it; CoreDNS' upstream
forwarder then becomes the local `tailscaled`. A `tailscaled` restart takes down all in-cluster DNS
(**C84**, as corrected — the earlier claim that the tailnet liveness probe would escalate this was refuted,
and `my.network.tailscale.liveness` is not enabled on yoga at all).

```nix
services.rke2.extraFlags = [ "--resolv-conf=/etc/rke2-resolv.conf" ];
```

`--resolv-conf` is the kubelet's resolv.conf file (`k3s/pkg/cli/cmds/agent.go:197-202`), and the file it
points at carries real upstream resolvers rather than the MagicDNS stub. mynixos writes it with
`environment.etc`, so it is a store-backed file with no runtime dependency on anything.

### Reverse-path filtering stays strict

`checkReversePath` is unset throughout mynixos and both host files, so NixOS's default of `true` applies
(`nixos/modules/services/networking/firewall.nix:201-209`) and the `nixos-fw-rpfilter` mangle chain is live
(`nixos/modules/services/networking/firewall-iptables.nix:126-131`). This is a **different mechanism** from
`net.ipv4.conf.*.rp_filter`, which is already `0` on yoga — setting the sysctl does nothing to the iptables
rule, and Cilium's `sysctlfix` only touches the sysctl (**C73**).

```nix
networking.firewall.logReversePathDrops = true;   # first bring-up only
```

(`nixos/modules/services/networking/firewall.nix:226-233`, which logs drops only while `checkReversePath` is
enabled — `firewall-iptables.nix:140`.)

**Turn logging on before anything else is changed**, so the question is answered by observation. If drops
appear, fix the specific cause. Do **not** pre-emptively set `checkReversePath = false`: that is a
fleet-wide security regression adopted for a capability nobody uses, since `toFQDNs` egress policy is out of
scope this run and Hubble needs neither it nor kube-proxy-replacement. A security regression adopted
pre-emptively is not a trade, it is a giveaway.

This is also the least-verified finding in the whole analysis. The mangle chain was verified present; whether
decapsulated overlay traffic actually fails `-m rpfilter --validmark` given Tailscale's own policy rule was
**never tested — no packet was observed being dropped** (`docs/k8s-fleet-decision.md:522-528`). The logging
step is the test.

### Shutdown ordering

The rancher unit sets `KillMode = "process"` (`nixos/modules/services/cluster/rancher/default.nix:922`),
which deliberately leaves containerd and every pod running when the unit stops. Nested pod mounts beneath a
persisted kubelet directory then block unmounting `/persist` at shutdown (**C87**).

- A shutdown-ordered unit running `rke2-killall.sh`, `Before = [ "umount.target" ]`. The script is installed
  into the package (`pkgs/applications/networking/cluster/rke2/builder.nix:125`) and wrapped with the tools
  it needs at `:126-130`.
- `services.rke2.gracefulNodeShutdown.enable = true`
  (`nixos/modules/services/cluster/rancher/default.nix:668-695`), which renders
  `shutdownGracePeriod` / `shutdownGracePeriodCriticalPods` into a KubeletConfiguration file passed as
  `--kubelet-arg=config=…` (`:886-897`, `:947`). Defaults are 30s and 10s (`:678`, `:688`).

**Assert a clean reboot in the VM test.** This failure appears only at shutdown, which no other assertion in
the suite reaches.

### The assertions this module must supply, because `services.rke2` has none

**`services.rke2` has no assertions at all.** A grep for `assertions` across
`nixos/modules/services/cluster/rancher/{default,k3s,rke2}.nix` returns exactly one hit —
`nixos/modules/services/cluster/rancher/k3s.nix:125`, on the k3s path. The rke2 path has none.

The join-contract checks that *do* exist are `lib.optional` entries in a **warnings** list
(`nixos/modules/services/cluster/rancher/default.nix:811`, with the serverAddr check at `:827-829` and the
token check at `:830-833`), and they are phrased "**should** be set if role is 'agent'". So a misconfigured
agent **builds, switches, and fails at runtime**, having emitted one line that `nixos-rebuild` scrolls past
(**C88**). The decision record credited the module with asserting this; it does not.

**C11** requires joining to be declarative and idempotent, and until this module supplies them there is no
eval-time enforcement of that anywhere. The cluster domain carries its own:

```nix
assertions = [
  {
    assertion = cfg.role == "agent" -> cfg.serverAddr != "";
    message = "my.infra.<cluster>: an agent needs serverAddr. services.rke2 only warns (rancher/default.nix:827), so without this the node builds, switches, and never joins.";
  }
  {
    assertion = cfg.role == "agent" -> cfg.tokenFile != null;
    message = "my.infra.<cluster>: an agent needs tokenFile. A string `token` would be rendered into the unit, which is a store path -- see my.secrets.allowSecretsInStore.";
  }
  {
    assertion = cfg.role == "server" -> cfg.tlsSan != [ ];
    message = "my.infra.<cluster>: a server needs a tls-san list BEFORE first start. The serving cert is generated once and persisted; adding a name later is imperative surgery, not a rebuild.";
  }
  {
    assertion = cfg.role == "agent" -> cfg.cni == null;
    message = "my.infra.<cluster>: cni is a server-side value; setting it on an agent is a no-op that reads as configuration (rancher/rke2.nix:127-129 warns).";
  }
  {
    assertion = cfg.enable -> config.my.secrets.enable;
    message = "my.infra.<cluster>: the join token comes from sops.";
  }
];
```

The last is the shape `my/dev/remote-builders/default.nix:27-31` already uses for the same reason. This is
the difference between a typo caught by `nix flake check` and a node that silently never joins.

## Kubeconfig access

**The current module makes the admin kubeconfig world-readable, and the option that does it defaults to
true.** A oneshot unit waits for the file and runs `chmod 644` on it (`my/infra/k3s/default.nix:44-58`, the
`chmod` at `:56`), driven by `kubeconfigReadable`, whose default is `true`
(`my/infra/options.nix:34-38`). The same code appears a second time in the runner module
(`my/infra/github-runner/default.nix:385-399`). That file embeds the cluster-admin client certificate *and
its private key*: mode 644 grants full, unauthenticated, unaudited cluster-admin to every local account and
every process on the host — a browser, a language server, a CI runner's job (**C43**).

`my/infra/k3s/default.nix:27-29` then sets `environment.variables.KUBECONFIG` to that file for every user on
the host, which is what turns the file mode into every shell's default credential (**C45**).

### The fix is a flag, not a unit

RKE2 has first-class options for this, and neither needs a `chmod`:

```
--write-kubeconfig-mode    k3s/pkg/cli/cmds/server.go:288-293
--write-kubeconfig-group   k3s/pkg/cli/cmds/server.go:294-299
```

with the mode parsed and applied where the file is written (`k3s/pkg/server/server.go:450-451`, inside
`writeKubeConfig` at `:416`). Neither is exposed by the nixpkgs module, so both go through `extraFlags`
alongside `--tls-san`.

**C44** names two acceptable shapes and nothing looser. Recommended, in order:

1. **`0600`, root-owned, plus a scoped credential for interactive use.**
   `--write-kubeconfig-mode=0600`, and interactive users get a *separate* client certificate or
   ServiceAccount token bound to a Role rather than `cluster-admin`, delivered as a sops secret at mode
   `0400` owned by that user — the existing idiom at `my/dev/remote-builders/default.nix:33-35` and
   `my/infra/radicle/default.nix:137-139`.
2. **`0640` root-owned with a dedicated group** whose membership is declared:
   `--write-kubeconfig-mode=0640 --write-kubeconfig-group=<group>`. The repo already scopes a service state
   directory this way (`my/network/monitoring/default.nix:26-27` uses `0750` for the same reason).

What is not acceptable: **any mode with a world bit**, and any arrangement that makes `cluster-admin` the
default identity of an interactive login session.

`KUBECONFIG` is not set fleet-wide. A per-user kubeconfig is per-user — home-manager — and pointing at one is
then not itself a grant.

**aether5d-dev's credential is decided at the same moment as `tls-san`, not later.** The Mac is a client, its
credential crosses the tailnet, and the SAN list must already contain the name it will dial. Issuing it a
scoped certificate then is one step; copying the admin file and regretting it later is two.

Note also that persisting `/etc/rancher` wholesale would drag this file into `/persist` — which is why the
State directories section persists `/etc/rancher/node` only (**C81**).

## What is not established

Kept in the tradition of `docs/k8s-fleet-constraints.md`: a reference that launders uncertainty is worse than
one that has gaps.

- **The reverse-path-filter interaction is reasoned, not observed.** The mangle chain is verified present and
  `checkReversePath` is verified unoverridden; whether decapsulated Cilium traffic actually fails
  `-m rpfilter --validmark` given Tailscale's own policy rule was never tested. This is the most consequential
  finding and the least verified one. `logReversePathDrops` on first bring-up is the test, and it must come
  first.
- **The 1.19.601-era `rke2-cilium` values patch cannot be read from disk.** The rke2-charts clone is one
  commit deep and its patch is generated against Cilium 1.20.1. The *direction* of each Rancher override is
  stable across versions and `hubble.enabled: false` is independently verified (**C69**), but the patch line
  numbers describe the 1.20.1-based fork.
- **Whether the cilium airgap tarball carries hubble-relay and hubble-ui** is not checkable without fetching
  it. One `crictl images` at bring-up settles it.
- **`/var/lib/kubelet`'s place in the persist list is carried from the Persistence table, not from C80/C92.**
  The surgical rewrites neither confirmed nor removed it.
- **Kernel fitness was measured on yoga only.** BTF, `BPF_LSM`, `CGROUP_BPF`, unified cgroup2, bpffs and the
  absence of lockdown were confirmed there. **skyspy-dev's pinned `linuxPackages_6_12` was never checked**,
  and **C48** requires the floor be met by 6.12 rather than by whatever yoga runs. Re-check before it joins.
- **No live observation of anything.** `cilium-dbg status --verbose` and `cilium-dbg debuginfo | grep -i mtu`
  on a real node would settle the device-selection and MTU claims in one command each. Neither has been run,
  because no cluster exists.
- **`cni.enableRouteMTUForCNIChaining` was read at `main`.** Its behaviour under `portmap` chaining at
  v1.19.6 is untested here. Pinning the MTU is what makes it unnecessary.
- **The etcd snapshot destination is deliberately unsettled.** RKE2's defaults are kept — every 12 hours,
  retention 5, into `server/db/snapshots` (`k3s/pkg/etcd/snapshot.go:73`) — which means **no recovery from
  the loss of yoga's disk**. The owner accepted this rather than block first bring-up on picking an off-box
  destination (**C95**, deferred at `docs/k8s-fleet-constraints.md:1143-1148`). If a custom directory is ever
  used, rke2 refuses to create a non-default one (`k3s/pkg/etcd/snapshot.go:80-84`), so mynixos must
  pre-create it — and **C105** records that a tmpfiles-created directory loses the race to the impermanence
  bind mount silently, with rke2 exiting 0. Copy out of the default directory instead of repointing it.
- **Secrets work is out of scope for this run** (**C106**). The irreducible sops ciphertext exists on one
  disk and `/home/logger/.secrets` holds an unrotated plaintext key; both are real and both belong to a
  separate session. The cluster's own token still goes into sops from the start, because that costs nothing
  now and is surgery later.
- **The whole dataplane is off the only CI-tested NixOS path.** `nixos/tests/rancher/default.nix:56-68`
  loads the canal image set and nothing else, so Cilium on NixOS is tested by nobody. That makes
  `tests/vm-rke2-cluster.nix` load-bearing rather than diligent, and it is why it is written before the
  implementation (**C72**). The departure is narrower than it sounds: the *wiring* — a `HelmChartConfig`
  through `services.rke2.manifests` — is exercised by `nixos/tests/rancher/multi-node.nix:115-126`. Only the
  CNI is untested.
