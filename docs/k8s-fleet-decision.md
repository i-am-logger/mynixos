# Kubernetes on this fleet: the decision

Status: **decided, not built.** This file records what was chosen, what it was scored against, and — the part
that makes it worth keeping — where the evidence is thin or argues the other way.

Its companion is `docs/k8s-fleet-constraints.md`, which was written before any candidate was named and which
this file does not get to edit. Where a constraint number appears below (**C1**, **C64**, …) the underlying
`file:line` for the fleet's own state lives there; it is not repeated here. Everything *new* — every claim about
an upstream project — carries its own citation into a clone read for this decision.

A decision record that only supports the decision is worthless, so §6, §9 and §10 exist to say what would have
gone the other way, what it costs to reverse, and what nobody has actually observed.

## 1. What was decided

| | Choice | Nature |
|---|---|---|
| Distribution | **RKE2** | owner-directed |
| CNI | **Cilium**, for Hubble observability specifically | owner-directed |
| Control plane | **yoga alone**, single server, no HA | follows **C7**, **C9** |
| Worker | **skyspy-dev** as an agent | follows **C8** |
| aether5d-dev | **client only this run**; the aarch64 Linux VM node is deferred | frozen spec, "Answers to the open questions" |
| IP stack | **single-stack IPv4** | frozen spec |
| Pod MTU | Cilium `MTU: 1280` knob → pod **route** MTU **1230** | **C66**, **C18** |
| CNI-level encryption | **none** — the tailnet already WireGuards it | frozen spec |
| `kubeProxyReplacement` | **off**, which is also RKE2's default | **C68** |
| `checkReversePath` | **stays strict**; `logReversePathDrops = true` on bring-up | **C73** |
| `toFQDNs` egress policy | **out of scope this run** | **C73** |
| NetworkManager `unmanaged-devices` | `my/system/core/default.nix:161` keeps ownership; nixpkgs' `rke2-canal.conf` is `mkForce`d off | **C74** |

Because the Mac VM node is deferred, **the cluster is single-arch `x86_64` for this run** and **C38**–**C41**
are forward-looking rather than live. They still shape one decision — see §5's note on airgap image attributes —
because a module that names an arch-suffixed attribute literally is one that cannot be built for the other
architecture later.

Three of these are not open questions and are recorded, not argued: the distribution, the CNI, and the reason
for the CNI. What follows scores them anyway, because a choice nobody scored is a choice nobody can revisit.

## 2. Provenance of the evidence

Three layers, in increasing order of how much weight they carry:

1. **The frozen constraint spec.** 74 constraints, every hard one traced to something already true in this
   repo, on these hosts, or in the pinned nixpkgs.
2. **Seven candidate assessments**, one per candidate, each returning verdicts, a strongest objection and its
   own unverified claims.
3. **A 26-agent upstream sweep** across 8 research angles. Eight high-impact claims went to adversarial
   verification and **seven were refuted or materially corrected**. That is the strongest evidence here, and it
   is strongest precisely because most of what it checked turned out to be wrong.

The clones read for this file are at `/tmp/rke2-fleet-research/{rke2,rke2-charts,k3s,k0s,talos,cilium,calico,tailscale}`.
The pinned nixpkgs is `/nix/store/c4ymw711a6r51sgvazgk9kvy1r6cxqhy-source`, where `pkgs.rke2` evaluates to
**1.35.7+rke2r1**.

**A caveat that applies to every Cilium citation below.** The cilium clone is at `main` — its `VERSION` file
reads `1.21.0-dev` — and the clone is shallow with no tags fetched. RKE2 ships a much older Cilium (§11). Every
`cilium/...` line number therefore describes *current upstream*, not the code that will run on this fleet. Where
the sweep found the two to differ, that is called out; where it did not check, the citation is weaker than it
looks.

## 3. Decision matrix: distributions

Verdicts carried through from the per-candidate assessments. **S** = satisfied, **NW** = needs work, **V** =
violated, **—** = not reached (candidate already disqualified on an earlier group).

| Constraint group | RKE2 | k3s | k0s | Talos |
|---|---|---|---|---|
| Availability in pinned nixpkgs | **S** | **S** | **V** | **V** (client only) |
| Platform reach — **C1**–**C6** | **S** | **S** | — | **V** |
| Topology / join surface — **C10**–**C12** | **S** | **S** | — | — |
| CNI bootstrap without deadlock | **S** | **V** | — | — |
| Declarative CNI customisation | **S** | **NW** | — | — |
| Networking + MTU — **C15**–**C25** | **NW** | **NW** | — | — |
| Secrets — **C26**–**C32** | **S** | **S** | — | — |
| Persistence — **C33**–**C37**, **C59**–**C63** | **NW** | **NW** | — | — |
| Mixed architecture — **C38**–**C42** | **S** | **S** | — | — |
| Security posture — **C43**–**C50** | **NW** | **NW** | — | — |
| **C64** NetworkManager clobber | **V** | **V** | — | — |
| **C65** unit ordering vs the tailnet | **NW** | **NW** | — | — |
| **C72** CI coverage on NixOS | **NW** | **NW** | — | — |

Reading the matrix honestly: RKE2 and k3s are near-identical on everything except two rows, and those two rows
are the whole decision.

**Both are the same nixpkgs module.** `services.rke2` and `services.k3s` share one `mkRancherModule` factory in
the pinned nixpkgs (`nixos/modules/services/cluster/rancher/`), so `serverAddr`, `tokenFile`, `role`,
`manifests` and `jsonManifests` exist identically for both. Everything the frozen spec calls a gap in the
*current* module — **C12**'s missing server address and token — is a gap in `my/infra/k3s`, not in what nixpkgs
offers.

**The row that decides it is CNI bootstrap.** RKE2 deploys the CNI as a packaged Helm chart marked
`bootstrap: true` (`rke2/charts/chart_versions.yaml:1-4`) and sets `FlannelBackend = "none"` in its own defaults
(`rke2/pkg/cli/defaults/defaults.go:26`), so a non-flannel CNI is a supported first-class value rather than a
subtraction. k3s has no CNI enum at all: running anything but flannel means `--flannel-backend=none`
(`k3s/pkg/cli/cmds/server.go:254`), which leaves the helm-controller job with no CNI to schedule on. Bootstrapping
Cilium then needs an out-of-band imperative step — exactly the shape the frozen spec's preferences react against,
and exactly what `my/infra/github-runner/default.nix:425` and `:433` already do wrong today.

**The second row is declarative customisation.** RKE2's `services.rke2.manifests` renders an attrset to JSON and
places it in the server's manifests directory as a systemd-tmpfiles `L+` symlink into `/nix/store`. That is what
makes a `HelmChartConfig` — the MTU pin, the Hubble switch, every value below — Nix rather than YAML applied by
a oneshot. `jsonManifests` exists at all because RKE2 opens `.yaml`/`.yml` manifests `O_RDWR`, which a read-only
store path cannot serve; the practical consequence is **do not give a manifest attribute a `.yaml` name**.

**k0s and Talos are disqualified before any feature comparison**, and both deserve the courtesy of saying so
plainly. k0s is simply absent from the pinned nixpkgs for both `x86_64-linux` and `aarch64-linux`, with no
`services.k0s` module — adopting it is a packaging project no capability justifies for three nodes. Talos is
arguably the best-engineered candidate in the field and would beat RKE2 on hardening outright, but it *replaces
the operating system* — "a modern OS for running Kubernetes: secure, immutable, and minimal"
(`talos/README.md:15`). yoga is a daily-driver desktop with secure boot, impermanence and the live Radicle
forge; a node cannot be both a Talos appliance and a NixOS workstation. `talosctl` is packaged for both arches,
so managing a *remote* Talos cluster from here stays possible — that is a different fleet.

## 4. Decision matrix: CNIs

RKE2's `cni` option is `nullOr (enum [ "none" "canal" "cilium" "calico" "flannel" ])` in the pinned nixpkgs
(`nixos/modules/services/cluster/rancher/rke2.nix`). The field is those five and nothing else without leaving
the supported path entirely (§7).

| Constraint group | Cilium | Calico | canal | flannel |
|---|---|---|---|---|
| NetworkPolicy enforced at all | **S** | **S** | **S** | **V** |
| Flow observability — category | **S** | **S** | **V** | **V** |
| Flow observability — depth (L7, DNS, drop reasons, service map) | **S** | **NW** | **V** | **V** |
| **C16**/**C66** MTU: correct without help | **S** | **V** | **V** | **V** |
| **C16**/**C66** MTU: knobs needed to fix | 1 | 1–2 | **2** | 2 |
| **C15** no L2 adjacency assumed | **S** | **S** | **S** | **S** |
| **C68** host mutation beyond the pod network | **NW** | **S** | **S** | **S** |
| **C73** works with strict reverse-path filtering | **NW** | **S** | **S** | **S** |
| `cisHardening` without owning an exception | **V** | **V** | **S** | **V** |
| **C72** CI-tested on NixOS | **V** | **V** | **S** | **V** |
| **C38**–**C41** multi-arch airgap images | **S** | **S** | **S** | **S** |
| `toFQDNs` egress policy (out of scope this run) | **S** | **V** | **V** | **V** |

**flannel is disqualified on one fact and it is not a close call.** RKE2's flannel chart patch deletes the
upstream `kube-network-policies` sidecar along with its values and its RBAC
(`rke2-charts/packages/rke2-flannel/generated-changes/patch/values.yaml.patch:87` removes the `netpol` block,
`:93` its image). NetworkPolicy objects are still accepted by the API server and enforce nothing. Silently-inert
security policy is strictly worse than no policy, because the second is visible.

**The `cisHardening` row is a real cost of every non-canal choice.** RKE2 registers the
`rke2-flannel-host-networking` policy controller — the thing that keeps host-network pods reachable under CIS
default-deny — only when the CNI list is empty or contains `canal`; anything else runs
`cisnetworkpolicy.Cleanup` instead (`rke2/pkg/rke2/rke2.go:80-83`, and
`rke2/pkg/controllers/cisnetworkpolicy/cleanup.go:21-23` is the removal path). Choosing Cilium means owning that
exception by hand if `cisHardening` is ever wanted. It is not wanted this run, and it is not free later.

## 5. Why RKE2

The distribution was owner-directed. Scoring it after the fact, the choice holds, and the reasons are the two
matrix rows above rather than anything about hardening or CIS profiles:

- **A non-flannel CNI is a config value, not a bootstrap problem.** This is the single property that makes the
  Cilium decision expressible in Nix at all.
- **Chart configuration is declarative.** `services.rke2.manifests` is the mechanism for the MTU pin, for
  enabling Hubble, and for every other value this design needs — one mechanism, not five.
- **Airgap images are per-architecture and versioned in lockstep.** The pinned nixpkgs exposes
  `images-cilium-linux-amd64-tar-zst` and `images-cilium-linux-arm64-tar-zst` (and the same `amd64`/`arm64`
  pairing for canal, calico, flannel, core) from `pkgs/applications/networking/cluster/rke2/1_35/images-versions.json`.
  **C40** is the constraint that says a module must select these as a function of `nixpkgs.hostPlatform` rather
  than naming one literally — moot while the fleet is single-arch, fatal on the day the Mac VM lands.
- **The join surface exists.** `serverAddr` and `tokenFile` are first-class in the shared rancher module, and
  the module asserts that an agent has both. **C12**'s gap closes by using what is already there.

What RKE2 costs, stated plainly: **you inherit a Rancher fork's defaults you did not choose and cannot bump
independently.** The chart pin (§11), `cni.chainingMode: portmap` (§8, risk R2) and `hubble.enabled: false`
(**C69**) are all decisions Rancher made. That is the price of the packaged-CNI model and it is not a
Cilium-versus-canal discriminator — canal is an equally forked, equally pinned Rancher chart.

## 6. Why Cilium, honestly

The CNI was owner-directed **for Hubble observability specifically** — not for L7 policy, not for ClusterMesh,
not for BGP, not for the egress gateway. That framing matters, because it is the only framing under which the
choice survives contact with the evidence.

### The margin is narrower than assumed, and here is where it actually is

The sweep set out to confirm that choosing canal or Calico meant giving up flow observability. **It found the
opposite.** Calico Open Source 3.30+ ships Goldmane (a flow-log aggregator) and Whisker (a live flow UI with
policy-verdict filtering), and both default to **enabled** upstream
(`calico/charts/tigera-operator/values.yaml:87-92`). RKE2 does not remove them; it merely flips them off in its
own chart fork (`rke2-charts/packages/rke2-calico/generated-changes/patch/values.yaml.patch:47-59`, which turns
`apiServer`, `goldmane` and `whisker` from `true` to `false`). A `HelmChartConfig` turns them back on, and the
images are already in RKE2's calico airgap set for both architectures.

So the honest statement is: **flow observability is not a Cilium monopoly. Hubble's advantage is depth, not
category.** What Hubble has that Whisker does not:

- **L7 / HTTP visibility** — Calico's is Enterprise.
- **DNS visibility.**
- **Per-flow eBPF drop reasons** — the single most useful thing when debugging an overlay.
- **The service map.**
- **The `hubble observe` CLI**, and Relay behind it.
- **Prometheus flow metrics.**

Set against a VXLAN overlay running inside WireGuard on a 1280-byte TUN, that list is not decoration. The
hardest failure this design can produce is a packet that leaves one pod and does not arrive at another, and
per-flow drop reasons are the difference between reading a cause and guessing one. That is the case for Cilium,
and it is the whole case.

### Three arguments for Cilium that the evidence does not support

Recorded so nobody rebuilds the case out of them later.

**"Cilium gets the MTU right and the others do not."** True but not decisive. Cilium's MTU manager takes
`min(dev.MTU)` over its selected devices (`cilium/pkg/mtu/manager.go:49-56`) and its device controller scans
**all** routing tables (`cilium/pkg/datapath/linux/devices_controller.go:82` uses `RT_TABLE_UNSPEC`), so
`tailscale0` is selected and it converges on 1280 unaided. Calico's Felix instead matches interfaces by *name*
against `MTUIfacePattern`, whose default `^((en|wl|ww|sl|ib)[Pcopsvx].*|(eth|wlan|wwan).*)`
(`calico/felix/config/config_params.go:517`) never matches `tailscale0` — `findHostMTU`
(`calico/felix/dataplane/linux/int_dataplane.go:1733`) therefore skips it and lands on the 1500 NIC. canal needs
*two* knobs, because `calico.vethuMTU` is hardcoded at 1450 in the chart
(`rke2-charts/packages/rke2-canal/charts/values.yaml:125`) and injected as `CNI_MTU` into the conflist
(`rke2-charts/packages/rke2-canal/charts/templates/config.yaml:24` and `:38`), independently of flannel's own
tunnel MTU. But the pin is being set anyway (§8), so the difference is one line versus two.

**This supersedes C16's framing, and the frozen spec says so at C65.** C16 said pod MTU must never be
auto-detected because autodetection would probe a 1500-byte NIC. For Cilium that is simply false. Pinning is
still right — as a *determinism* fix across differently-shaped machines, and as compensation for a self-heal
that does not exist here (§8, R2) — not because the autodetector computes the wrong answer.

**"eBPF in yoga's host cgroup root."** Not the default and not what is being adopted. RKE2's `rke2-cilium` values
patch never sets `kubeProxyReplacement`, so upstream's `kubeProxyReplacement: "false"`
(`cilium/install/kubernetes/cilium/values.yaml:2470`) stands and RKE2 keeps deploying its own kube-proxy. The 13
cgroup2-root BPF programs are an opt-in that this design does not take (**C68**). Two host mutations happen
regardless of that switch — an init container nsenters PID 1 to mount a second cgroup2 at
`/run/cilium/cgroupv2`, and `sysctlfix` writes `/etc/sysctl.d/99-zzz-override_cilium.conf` and restarts
`systemd-sysctl`. On a tmpfs root both are ephemeral by construction, and the sysctl write is removable at the
root cause: `sysctlfix.enabled = false` plus the same rules in `boot.kernel.sysctl`.

**"An over-large pod MTU silently black-holes."** **C67 refutes C20 for this stack**, and this correction matters
more than it looks because C20 is the stated reason the constraints file exists. Cilium sets neither `DF` on
`cilium_vxlan` nor `BPF_F_DONT_FRAGMENT`, and `skb_tunnel_check_pmtu` neither drops nor ICMPs for a
non-bridge-port device — so an oversized outer packet is **IP-fragmented by the local kernel** to ≤1280, carried
by Tailscale, and reassembled at the peer. RKE2's chart additionally ships
`pmtuDiscovery.packetizationLayerPMTUDMode: "blackhole"`, and cilium-cni sets `tcp_mtu_probing=1` in every pod
netns — RFC 4821 PLPMTUD, which recovers TCP without ICMP at all. The real symptom is **throughput collapse,
reassembly pressure and loss amplification**, not a hang. UDP and QUIC get no PLPMTUD rescue.

The consequence for the test suite is concrete and easy to get wrong: **a VM test that only asks "did a large
payload arrive" passes on a misconfigured cluster**, because fragmentation makes it arrive. The test must assert
the pod's **route MTU** directly, which is what **C18**'s 1230 is for.

### What is being bought that this fleet does not use

Three nodes, one of them absent half the time, every inter-node byte already inside WireGuard. Identity policy
at scale, ClusterMesh, BGP, the egress gateway and kube-proxy-replacement throughput all answer problems this
fleet does not have. Hubble is the feature that pays, and **C69** records that RKE2 ships it *disabled*
(`rke2-charts/packages/rke2-cilium/generated-changes/patch/values.yaml.patch:60-63` flips
`hubble.enabled` from `true` to `false`). Turning it on is one `HelmChartConfig` through the same mechanism as
everything else — so it costs nothing new, but **Cilium alone buys no observability at all** until that config
lands. Hubble is a milestone, not a side effect.

## 7. The case where canal would have won

Canal very nearly wins, and the reasons are structural rather than aesthetic. Stated in full, because the
condition to revisit is at the end and it is only meaningful if the case is put fairly.

1. **It is RKE2's default.** Leave `cni` unset and canal is what runs.
2. **It is the only CNI nixpkgs CI-tests on NixOS.** The `nixos/tests/rancher/` suite in the pinned nixpkgs
   pulls `images-core-*` and `images-canal-*` and nothing else (`nixos/tests/rancher/default.nix`, the image
   list), on both architectures — and it pins the flannel interface through exactly the
   `services.rke2.manifests` HelmChartConfig mechanism this fleet needs, with an in-tree comment saying RKE2's
   canal *has* to be configured that way (`nixos/tests/rancher/multi-node.nix`). Choosing canal means running
   the one dataplane NixOS actually tests.
3. **It is the only CNI that keeps `cisHardening` working without owning an exception** (§4).
4. **It needs no reverse-path-filter relaxation.** Under **C73** that is a live concern for Cilium and a
   non-concern for canal.
5. **It is fewer moving parts**, which the frozen spec lists as a preference and which is the correct
   preference for one always-on desktop.

Canal loses on exactly one axis — observability — and that axis happens to be the one the CNI was chosen for.
Canal is a manifest install with no tigera-operator, and Tigera does not support Whisker on manifest installs;
Felix does carry a `flowLogsGoldmaneServer` setting, so a hand-rolled aggregator is technically plumbable, but
unsupported and not a thing to build a fleet on.

Note what this does to the runner-up ordering: **on observability, Calico beats canal.** If the requirement is
"flow visibility" rather than "Hubble-depth flow visibility", the correct fallback is `cni = "calico"`, not
canal. Calico's one hard gap is FQDN egress policy — verified absent at v3.32: `NetworkSetSpec` is
`Nets []string` with CIDR validation and nothing else (`calico/api/pkg/apis/projectcalico/v3/networkset.go:48-53`),
and a tree-wide grep for `AllowedEgressDomains`, `DNSPolicyMode` and `toFQDNs` returns nothing. That gap is out
of scope this run (**C73**), which is precisely what makes Calico competitive here.

> **Revisit condition.** Reconsider canal if any of these becomes true:
>
> - **Hubble is not actually enabled and used within one milestone of the cluster coming up.** If the
>   `HelmChartConfig` of **C69** does not land, Cilium has bought a departure from the CI-tested path in
>   exchange for nothing.
> - **`cisHardening = true` becomes wanted.** Canal is the only value that keeps `rke2-flannel-host-networking`
>   maintained; anything else means owning the host-network exception by hand (`rke2/pkg/rke2/rke2.go:80-83`).
> - **`tests/vm-rke2-cluster.nix` is not written, or is written without modelling the firewall.** Per **C72**
>   that test is load-bearing rather than diligent, and an unmodelled firewall gives false confidence on exactly
>   the finding ranked most uncertain (§10).
> - **Reverse-path drops are observed and the only fix on offer is a fleet-wide `checkReversePath = false`.**
>   **C73** is explicit that the fix must be the specific cause. If it cannot be, the trade has become "strict
>   anti-spoofing on the always-on node, for Hubble" and that trade should be made deliberately or not at all.

## 8. Rejected alternatives, one line each

| Candidate | Why not |
|---|---|
| **k3s** | CNI bootstrap deadlock: no `cni` enum, so a non-flannel CNI means `--flannel-backend=none` (`k3s/pkg/cli/cmds/server.go:254`) and the helm-controller job has nothing to schedule on. |
| **k0s** | Not packaged in the pinned nixpkgs for either architecture, and no `services.k0s` module. Adopting it is a packaging project. |
| **Talos** | Replaces the operating system (`talos/README.md:15`); yoga and skyspy-dev are workstations first and cluster nodes second, and there is no spare machine. |
| **flannel** | RKE2 patches out its NetworkPolicy sidecar, so policy is accepted and silently inert (`rke2-charts/packages/rke2-flannel/generated-changes/patch/values.yaml.patch:87`, `:93`). |
| **Weave** | Archived June 2024. (The nixpkgs package named `weave` is an unrelated Rust binary — a live false positive for anyone grepping.) |
| **kindnet** | Archived October 2025. |
| **Antrea** | Does not start on NixOS unmodified: `install_cni` runs under `set -euo pipefail` and greps `/lib/modules/$(uname -r)/modules.builtin`, and `/lib` does not exist. |
| **kube-router** | Ships no Helm chart, so it is the one candidate that cannot use RKE2's declarative manifest path at all. |
| **Kube-OVN** | Plants a second stateful control plane (ovn-central NB/SB) on the node deliberately kept simple. |
| **A plain kernel-WireGuard underlay** instead of the tailnet | Not rejected on speed — that argument was refuted by its own citation. Rejected because it is hub-and-spoke without NAT traversal or relay, and nix-darwin has no WireGuard module, so the Mac would run userspace WireGuard anyway. |

The last five rows have **no clone on disk** — Antrea, kube-router, Kube-OVN, Weave and kindnet were read by the
sweep and are not re-checkable here. They are recorded as sweep findings and carry no `file:line`, deliberately,
rather than a citation that would look stronger than the evidence.

## 9. Top risks, with mitigations

Ordered by how much they hurt, not by how likely they are. The first is not a Kubernetes problem and the second
is not a CNI problem, which is the point.

### R1 — `services.rke2.enable = true` repoints four kernel sysctls, machine-wide, ungated

**The single highest-hurt item in the analysis, and it has nothing to do with which CNI you pick.** In the
pinned nixpkgs' `nixos/modules/services/cluster/rancher/rke2.nix`, a `boot.kernel.sysctl` block sits inside
`config = lib.mkIf cfg.enable` — *not* inside the `cisHardening` guard, which begins one attribute later and
covers only the etcd user — and the values are plain, not `mkDefault`:

```
vm.panic_on_oom = 0; vm.overcommit_memory = 1; kernel.panic = 10; kernel.panic_on_oops = 1;
```

`panic_on_oops = 1` plus `panic = 10` converts a recoverable amdgpu oops on a daily-driver Hyprland desktop into
a hard reboot ten seconds later — and yoga's `/` is a 16 GB tmpfs, so that reboot discards the entire root
filesystem. This is the machine whose `my/forensics/` devcoredump capture path exists specifically to *survive*
that class of event. It fires on the one line that enables RKE2.

**Mitigation:** override all four with `lib.mkForce` in the cluster domain's implementation, per key, because
they are not `mkDefault`. Assert the resulting values in the VM test, so a nixpkgs bump that adds a fifth key is
a test failure rather than a surprise reboot.

### R2 — the NetworkManager `rke2-canal.conf` clobber, under the live Radicle forge

`my/system/core/default.nix:161` writes `unmanaged-devices` with the `podman*`, `docker*` and `br-*` entries
that keep NetworkManager's hands off the **running** forge. The nixpkgs rke2 module writes its own
`environment.etc."NetworkManager/conf.d/rke2-canal.conf"` setting the *same key* (in `rke2.nix`, guarded only on
`config.networking.networkmanager.enable`). NetworkManager reads `conf.d` in lexical order and a later file wins
for the same key; `'9'` is 0x39 and `'r'` is 0x72, so **`rke2-canal.conf` sorts last and wins**, silently
dropping the podman and bridge exclusions. NetworkManager then runs DHCP on `podman*` and takes the interface
down under a running container. **The failure will look like a Radicle problem.**

This is required whatever CNI is chosen. It is not a Cilium cost.

**Mitigation, per C74:** `environment.etc."NetworkManager/conf.d/rke2-canal.conf".enable = lib.mkForce false`,
and `my/system/core/default.nix:161` stays the single owner, extended with Cilium's interfaces —
`cilium_host`, `cilium_net`, `cilium_vxlan`, `lxc*`. There are currently **three** writers of this key; the
other two (`my/infra/k3s/default.nix:33` and `my/infra/github-runner/default.nix:329`) are removed in the same
milestone (§12). Ownership deliberately does *not* move into the cluster domain: core's list protects a workload
that has nothing to do with Kubernetes.

### R3 — nothing orders rke2 after `tailscaled`, and this breaks four things at once

The shared rancher unit in the pinned nixpkgs orders only `after`/`wants` on `firewall.service` and
`network-online.target` (`nixos/modules/services/cluster/rancher/default.nix`, the unit's `after` list). Neither
implies a tailnet address. Everything tailnet-dependent is therefore computed in a window where `tailscale0` may
not exist: `--node-ip`, the apiserver advertise address, kubelet registration, and the agent's `serverAddr`.
Without `--node-ip` the kubelet's interface choice falls to the default route — on yoga a LAN address no
off-site node can reach.

**This is the root cause and the MTU pin is insurance** (**C65**). Fixing the number without fixing the ordering
fixes one symptom of four.

**Mitigation:** `systemd.services.rke2-server.after = [ "tailscaled.service" ]` (and the agent equivalent) plus
an `ExecStartPre` that blocks until the node's `100.64.0.0/10` address is present. Set `--node-ip` explicitly
per **C24**. One further detail from the sweep, worth carrying because it is easy to get backwards: the agent's
`serverAddr` should be the literal tailnet IP rather than the MagicDNS name, because tailscaled's resolver is
not up when rke2 starts — which sits in tension with **C23**'s preference for names, and should be resolved by
making the *node identity* a name and the *bootstrap address* an IP, not by relaxing C23.

### R4 — `cni.chainingMode: portmap` disables Cilium's endpoint-MTU updater

RKE2's fork sets `chainingMode: portmap` with the comment "Otherwise rke2 hostPort does not work! Used for
nginx" (`rke2-charts/packages/rke2-cilium/generated-changes/patch/values.yaml.patch:22-25`). Cilium refuses to
register the endpoint-MTU updater whenever the chaining mode is not `"none"` and neither the CNI config nor the
agent config asks it to manage route MTU in chaining mode
(`cilium/pkg/mtu/endpoint_updater.go:71-80`; the flag defaults to `false` at `cilium/pkg/mtu/cell.go:75`).

So Cilium's MTU manager rewrites its statedb table on every device change and **nothing propagates it to running
pods**. A device-MTU change never reaches a pod created before it. That set is precisely the boot-time system
pods — CoreDNS, metrics-server, ingress.

**Mitigation:** pin `MTU: 1280` top-level in the `rke2-cilium` values, which makes the configured MTU non-zero
and skips the manager path entirely (`cilium/pkg/mtu/cell.go:144-167`). Understand what the pin is doing: it is
compensating for a missing self-heal, not preventing an outage. **The knob reads 1280 and the pod route MTU it
yields is 1230** (**C66**) — setting the knob to 1230 would yield 1180. 1280 is a hard floor because it is the
IPv6 minimum MTU; single-stack IPv4 was chosen, so this does not bite, but it is why the route MTU cannot be
lowered further. Assert 1230 in the VM test (**C18**, **C58**), directly as the pod's route MTU rather than by
sending a large payload (§6).

Do not turn `enableRouteMTUForCNIChaining` on as a workaround without testing it: this fleet's Cilium is 1.19.x
(§11) and the flag was read here at `main`.

### R5 — the container image store on yoga's 16 GB tmpfs root

If `/var/lib/rancher` is not persisted, every image pulled after a reboot is **resident RAM**, competing with
the 28 GB `/tmp` and 16 GB `/tmp/gpu-workdir` tmpfs on the same machine. That is a memory-exhaustion path, not a
slow start. The repo already knows the shape of this bug and already fixed it once for rootless podman
(`my/dev/development/default.nix:192-194`).

**Mitigation, per C61:** under RKE2 the image store lives beneath the distribution's state root, so persisting
`/var/lib/rancher` covers it — no separate declaration. `/persist` has ample free space; the RAM cost of *not*
doing it is the consideration. Declared per **C59**'s shape: one expression in the domain's implementation with
terms gated per role (**C60**), never a flat unconditional list.

### R6 — node identity is two paths, and persisting one is worse than persisting neither

`/var/lib/rancher` is not the whole of a node's identity. The node-password file is created on first
registration if absent and read on every subsequent one (`k3s/pkg/agent/config/config.go:205-221` — RKE2
embeds k3s here), and a mismatch against the server's stored hash is a hard registration failure reading
`Node password rejected, duplicate hostname` (`k3s/pkg/agent/config/config.go:180`) — an error that points
nowhere near impermanence. The sweep places that file under `/etc/rancher/node/password`; the path constant was
not confirmed in the clone, so treat the *path* as sweep-reported and the *mechanism* as verified.

Persist `/var/lib/rancher` alone and every reboot fails re-registration. Persist neither and it self-heals.
There is no `systemFiles` in `my.system.persistence.features` — only `systemDirectories`, `userDirectories` and
`userFiles` (`my/storage/impermanence/options.nix:53-63`) — so this must be the directory `/etc/rancher`, which
drags the generated kubeconfig and any registry configuration into `/persist` with it. That is a separate
decision and it interacts with **C43**'s file mode.

**Mitigation:** persist `/var/lib/rancher` and `/etc/rancher` together or neither, and make the VM test reboot a
node and assert it rejoins with the same identity (**C10**, **C11**). Do **not** persist `server/manifests` —
nixpkgs places `L+` tmpfiles symlinks into `/nix/store` and never prunes, so a manifest whose attribute is later
renamed dangles in `/persist` forever and the deploy controller keeps applying it.

### R7 — departure from the only CI-tested NixOS path

Per **C72**, `nixos/tests/rancher/` exercises canal only. Choosing Cilium means the fleet's dataplane runs on a
configuration nobody CI-tests on NixOS.

**Mitigation:** `tests/vm-rke2-cluster.nix` is **load-bearing, not diligent**, and per the plan it is written
*before* the implementation. The shape to copy is `tests/vm-radicle.nix`: two VMs on an isolated network, which
is what makes "private network" true by construction rather than by configuration (**C55**). It must model the
firewall — see §10 — and assert the pod route MTU as a number (**C58**).

### R8 — RKE2's default ingress-nginx will fight `tailscale serve` for :443 on yoga

`tailscale serve` holds :443 on yoga's tailnet address today. RKE2's ingress-nginx is a hostNetwork
**DaemonSet**, so it claims 80/443 on every node it lands on. Whichever binds first wins; if nginx wins, the
Radicle explorer path breaks silently.

**Mitigation:** `disable = [ "rke2-ingress-nginx" ]` and front ClusterIPs with `tailscale serve` instead — which
is also the answer to "how does anything get exposed", and which keeps one owner for :443.

### R9 — systemd-oomd's kill set already contains every pod

`my/system/core/default.nix:136` sets `enableRootSlice = true` unconditionally — not `mkDefault`. `kubepods.slice`
is a direct child of the cgroup root, so every pod is a candidate from day one. A `cilium-agent` SIGKILLed by
oomd is a whole-node network outage that will read as a Cilium bug.

**Mitigation:** decide this deliberately rather than discovering it. Backing it off needs `mkForce` and is a
mynixos change, not a Kubernetes one; the alternative is a per-slice `ManagedOOMPreference` for `kubepods.slice`.
Either way it belongs in the bring-up milestone, not after the first outage.

### R10 — `tls-san` has no nixpkgs option, and adding one later is imperative

A grep of the whole rancher module directory for `tls-san` / `tlsSan` / `write-kubeconfig` returns nothing.
aether5d-dev's kubectl over MagicDNS needs `yoga.tail46cce1.ts.net` in the serving certificate, so this is on the
critical path for a third of the fleet (**C5**). Adding a SAN after the fact is not a rebuild: it means deleting
the serving-cert secret *and* moving the dynamic-cert state aside — against state that lives inside the
persisted directory, so the impermanence wipe that would otherwise self-heal it does not.

**Mitigation:** write the SAN list before the cluster first starts, via `configPath` or `extraFlags`, and
include every name any client will ever dial. Decide aether5d-dev's credential at the same time (**C44**): the
Mac is a client, its credential crosses the tailnet, and that is the natural moment to issue a scoped user
certificate rather than copy the admin file.

### R11 — version skew across a laptop that is away for months

`pkgs.rke2` is `rke2_stable`, which is an alias — `rke2_stable = rke2_1_35` in
`pkgs/applications/networking/cluster/rke2/default.nix` of the pinned nixpkgs — and that alias moves on a
nixpkgs bump. skyspy-dev boots Windows for months, rebuilds against a moved unstable, and comes back two minors
off. An agent newer than the server does not join.

**Mitigation:** pin `services.rke2.package` explicitly from one shared place that both hosts read — the way this
repo already pins vogix to a tag rather than a branch.

### R12 — reverse-path filtering, re-installed several times a day

**C73** keeps strict filtering. The NixOS mangle chain with a DROP default is torn down and recreated by
`firewall-reload` on every `nixos-rebuild switch`, and yoga rebuilds many times a day — so if this does turn out
to bite, no imperative workaround can hold and the fix must be the Nix option.

**Mitigation, in order:** `networking.firewall.logReversePathDrops = true` on the **first** bring-up, before
anything else is changed, so the question is answered by observation. If drops appear, fix the specific cause.
Do not pre-emptively set `checkReversePath = false` — that is a security regression adopted for a feature nobody
uses (`toFQDNs` is out of scope), which is not a trade.

### R13 — shutdown ordering against a persisted state directory

The rancher unit sets `KillMode = "process"` (`nixos/modules/services/cluster/rancher/default.nix`, the unit's
`serviceConfig`), which deliberately leaves containerd and every pod running when the unit stops. Nested pod
mounts under a persisted kubelet directory then block unmounting `/persist` at shutdown.

**Mitigation:** a shutdown-ordered unit running `rke2-killall.sh` `Before = [ "umount.target" ]`, plus
`gracefulNodeShutdown`. Assert a clean reboot in the VM test rather than trusting it.

### R14 — DNS and the datapath share a failure domain

yoga's `/etc/resolv.conf` points at MagicDNS (100.100.100.100), which is a valid global unicast address, so the
kubelet's loopback detection does not fire and it hands that resolver to every pod. CoreDNS' upstream forwarder
then becomes the local tailscaled. If tailscaled restarts — or the tailnet liveness probe added in
`feat(network): a tailnet liveness probe that takes a dead role down` takes the node down — *all* in-cluster DNS
dies, not just cross-node traffic.

**Mitigation:** point `--resolv-conf` at a file carrying real upstreams, so the cluster's name resolution does
not depend on the same daemon as its dataplane.

## 10. What is NOT established

Carried forward from the sweep's own stated blindspots, because a decision record that launders uncertainty is
the failure mode this section exists to prevent.

- **The reverse-path-filter interaction is reasoned from a live rule, not observed.** The mangle chain with its
  DROP default was verified as present, and `checkReversePath` was verified as unoverridden anywhere in `my/`.
  Whether decapsulated overlay traffic actually fails `-m rpfilter --validmark` given Tailscale's own policy
  rule was **not tested** — no packet was observed being dropped. This is the finding ranked most consequential
  and it is the least verified. R12's logging step is the test, and it must happen first.
- **Kernel fitness was measured on yoga only.** BTF, `BPF_LSM`, `CGROUP_BPF`, unified cgroup2, bpffs and the
  absence of kernel lockdown were all confirmed live on yoga. **skyspy-dev's pinned `linuxPackages_6_12` was
  never checked** (**C48** requires the floor be met by 6.12, not by whatever yoga runs), and the Mac guest's
  kernel does not exist yet. Re-check before skyspy-dev joins.
- **The orphaned-pod / tmpfs finding is marked *likely*, not verified.** The upstream failure mode and its
  trigger were confirmed, and yoga's tmpfs root was confirmed; what was **not** reproduced is that RKE2's
  kubelet leaves pod volume paths populated across a tmpfs-root boot specifically. `KillMode = "process"`
  (R13) argues that it does; a clean `gracefulNodeShutdown` drain argues that it might not. This is why R6's
  mitigation is "persist both or neither" rather than a finer split the option surface cannot express anyway.
- **Every Cilium citation in this file is against `main` (1.21.0-dev), not the 1.19.x RKE2 ships** (§2, §11).
  The MTU-manager behaviour, the endpoint-updater gate and the configured-MTU short circuit were all read at
  `main`. The sweep found at least one place where the two genuinely differ — the fallback when no device is
  selected, which exists at `main` (`cilium/pkg/mtu/manager.go:58-62`) and does not on 1.19.x. Treat every other
  Cilium line number as *probably* the same and *not confirmed* the same.
- **Nobody has established that a NixOS VM test can exercise the rpfilter interaction at all.** A
  `tests/vm-rke2-cluster.nix` that does not model the firewall would give false confidence on precisely the
  finding ranked first here.
- **No live observation of anything.** `cilium-dbg status --verbose` and `cilium-dbg debuginfo | grep -i mtu`
  on a real node would settle the device-selection and MTU claims in one command each. Neither has been run,
  because no cluster exists.
- **The microVM placement question was raised and not priced.** The sweep's closing argument is that every risk
  in §9 that is *about yoga* — R1, R2, R8, R9, R12, R14 — evaporates if the server runs as a guest on yoga
  rather than as yoga. It did not cost the proposal: no RAM figure, no measurement of what nesting does to
  pod-to-pod latency on an underlay with zero MTU headroom, and no check of whether a guest can hold a tailnet
  identity cleanly enough to be the endpoint the other nodes address. That last constraint may kill it. It is
  recorded here as an unpriced alternative rather than a rejected one, because it was never scored.

One further thing the sweep said that this file will not bury: **the workload is not yet named.** The cross-repo
plan files contain no Kubernetes work item, and the previous attempt at this stack
(`my/infra/github-runner/default.nix`) was written, never enabled on any host, and never touched again. That is
not an argument against the decision — the decision is the owner's — but it is the honest context for §11's
reversibility numbers, which are small only because there is nothing running to migrate.

## 11. Where the evidence disagreed with itself

**The `rke2-cilium` chart pin: 1.19.601 versus 1.20.1.** Two sweep agents reported different numbers, and the
assessment for RKE2 flagged it as unverified rather than picking one. Both agents were right about the tree they
read, and **they read different trees**:

- `rke2/charts/chart_versions.yaml:1-4` — at the rke2 clone's HEAD — pins `rke2-cilium` at **1.19.601**, i.e.
  Cilium v1.19.6.
- `rke2-charts/packages/rke2-cilium/package.yaml:1` — at the rke2-charts clone's HEAD — builds from
  `https://helm.cilium.io/cilium-1.20.1.tgz`, i.e. upstream **1.20.1**, with `packageVersion: 03`.

The rke2-charts monorepo is where charts are *built*; `chart_versions.yaml` in the rke2 repo is what a given
RKE2 *release* ships. A newer base in the monorepo says nothing about what the pinned release carries.

**Neither number is confirmed to be what this fleet will run**, because both clones are at their default branch
and the pinned `pkgs.rke2` is **1.35.7+rke2r1**. What settles it, and should be run before anyone relies on a
Cilium version: fetch tags in the rke2 clone and read `charts/chart_versions.yaml` at the tag matching
`pkgs.rke2.version`. Until then, the safe statement is the one both agents agree on — **RKE2 ships a Cilium one
minor behind upstream stable, and it cannot be bumped without bumping RKE2.** That is a property of the
packaged-CNI model, not a Cilium-versus-canal discriminator: canal is an equally forked, equally pinned Rancher
chart.

A second, smaller disagreement worth recording: the sweep contains two accounts of how badly canal degrades when
a node vanishes, and the adversarial pass **refuted the stronger one in both directions** — flannel has strictly
fewer reconcilers than canal, so canal cannot win that criterion; and Calico's IPAM garbage collection keys on
node *existence*, never on readiness, so a `NotReady` node never loses its block affinities. The usable
conclusion is narrow: pick canal for simplicity if you pick it, not for graceful degradation.

## 12. Reversibility

RKE2's `cni` is a config key, which is the reason this is not a one-way door. Quantified, per choice:

| Choice | What changing it costs | One-way? |
|---|---|---|
| **CNI: Cilium → canal or calico** | One enum value in the pinned nixpkgs' `cni` option, plus ~3 supporting edits: the `HelmChartConfig` values (MTU knobs — canal needs two), the CNI interface names in `my/system/core/default.nix:161`, and the VM test's assertions. Plus a **full cluster re-bootstrap** — RKE2 does not swap a CNI live. | **No**, while there is no persistent workload. See the expiry condition below. |
| **Distribution: RKE2 → k3s** | The mynixos module shape survives intact: both are the same `mkRancherModule` factory with the same `serverAddr`/`tokenFile`/`manifests` surface. What does not survive is the packaged-CNI property, which is the reason RKE2 was chosen — so this is really "revert to flannel, or take on an imperative CNI bootstrap". | Effectively yes, for the CNI decision. |
| **Topology: single server → HA** | Needs a third always-on member. **C9** is arithmetic, not preference: two members give quorum 2, which is strictly *less* available than one. This fleet has one always-on machine. | Blocked by hardware, not by design. |
| **aether5d-dev: client → node** | A new module that provisions an aarch64 Linux VM (**C13** records that nothing does this today), plus **C38**–**C41** becoming live, plus an `aarch64-linux` build path the fleet does not have (**C41**). | No, but it is a project. |
| **`kubeProxyReplacement`: off → on** | Three coupled changes, not one flag: KPR itself, `k8sServiceHost`/`k8sServicePort`, unwinding `cni.chainingMode: portmap`, and `--disable-kube-proxy` on the server. It also attaches BPF programs at the cgroup2 root above every host process. | Reversible, but never one line. |
| **Hubble: off → on** | One `HelmChartConfig` through `services.rke2.manifests`. | No. |
| **MTU knob** | One values key — but with `portmap` chaining the endpoint updater is not registered (R4), so a changed value does not reach running pods. Changing it in practice means restarting every pod. | No, with a restart. |
| **`checkReversePath`: strict → loose** | One NixOS option, one rebuild — the **cheapest thing here to reverse and the most expensive to get wrong**, because it is fleet-wide and it weakens anti-spoofing on the node that publishes services to the tailnet. | Trivially reversible; that is exactly why it must not be changed casually. |
| **Persistence declarations** | Adding a directory is one term in the domain's `optionals` expression (**C59**). Removing one after a cluster has run is not symmetric: `/var/lib/rancher` holds the CA, and a regenerated CA is a *different* cluster wearing the old hostname. | Adding: no. Removing: yes, destructively. |

> **When CNI reversibility expires.** The "one enum value plus a re-bootstrap" figure holds only while a
> re-bootstrap costs nothing — no PersistentVolumes, no in-cluster state anyone would miss. RKE2 ships **no**
> storage provisioner and no default StorageClass (unlike k3s, which bundles local-path), so the first PVC will
> force a decision, and the obvious answer pins each volume to its creating node — which on skyspy-dev means
> unreachable the moment it boots Windows. **The day the cluster holds state worth keeping is the day this
> choice becomes expensive to revisit.** Revisit canal, if it is going to be revisited, before then.

## 13. Disposition of the existing modules

Neither existing module is a baseline to stay compatible with — **C69**'s scope note and the frozen spec's
"Out of scope" section both say so, and the correction notice records why: **yoga runs no cluster today.**
`my.infra.k3s` is never set in the host file and `github-runner.enable = false`, so this deploy tears nothing
down. What *is* live on yoga is the Radicle forge as rootless-podman roles, which must survive untouched — R2 is
the risk that it does not.

- **`my/infra/k3s` is dead code that the new cluster domain replaces, not coexists with.** It cannot express
  **C12** (no server address, no token), contributes no persistence (**C33**), `chmod 644`s the admin
  kubeconfig (`my/infra/k3s/default.nix:56`, driven by an option that defaults to `true` — **C43**), opens the
  API port on every interface (`my/infra/k3s/default.nix:38-41` — **C21**, **C46**), hardcodes one CNI's
  interface names as trusted (`my/infra/k3s/default.nix:40` — **C22**), and sets `KUBECONFIG` fleet-wide to the
  admin file (`my/infra/k3s/default.nix:28` — **C45**). It also writes the NetworkManager key a second time
  (`my/infra/k3s/default.nix:33` — **C74**). Removed whole.
- **`my/infra/github-runner` keeps its runner concern and loses its cluster concerns.** It currently carries a
  duplicated `services.k3s` block (`my/infra/github-runner/default.nix:314`), the third writer of the
  NetworkManager key (`:329`), the fleet-wide `KUBECONFIG` (`:323`), the same `chmod 644`, and an unconditional
  flat persistence list for a cluster it does not own (`:494-500`) — which is both incomplete (no
  `/etc/rancher`) and undifferentiated (no role gating), so per **C62** it is **replaced by the domain's
  declaration rather than relocated verbatim**. Its `kubectl apply -f <github URL>` and `helm repo add` at
  activation (`:425`, `:433`, `:471`, `:479`) violate **C50** and are not carried forward in any form.
  Re-enabling ARC is its own decision with its own constraints and is out of scope here.
- **Both move in the same milestone**, because leaving either in place leaves a second owner of the
  NetworkManager key and a second `services.<dist>` block.
- **The reach entry moves with them.** `tests/user-option-reach.nix:149` currently reads
  `"infra" = "k3s, the self-hosted GitHub runner, and the Radicle forge …"`. Per **C4** that string is updated
  to name the cluster domain, and the test fails until it is — which is the mechanism working as designed.

Client tooling for aether5d-dev arrives entirely separately, per **C5** and **C6**: `kubectl`, `k9s` and `helm`
as per-user `mkApp` modules under `my/users/apps/dev/`, imported from `platforms/common.nix` beside `devenv`,
`direnv` and `jq` (`platforms/common.nix:138-143`). Not from `my.infra`, which would make client tooling a
Linux-only concept; not from `my/system/base-packages`, which is the unconditional set every machine gets.

## 14. Open items the owner should settle

Not risks — decisions this file deliberately did not make.

1. **sqlite or embedded etcd.** The topology is right and the *stated reason* for it is wrong, so it is recorded
   rather than quietly repeated. **C9**'s quorum arithmetic is sound as a reason not to run a two-member
   control plane — but an **agent is never an etcd member**, so skyspy-dev booting Windows could not have
   affected quorum either way, and a single-server embedded-etcd cluster already has quorum 1. Separately, RKE2
   does **not** default to sqlite: `rke2/pkg/cli/defaults/defaults.go:24` sets `ClusterInit = true`, and the
   sqlite/kine path is reachable only by overloading `--disable-etcd` — RKE2's own source calls it that: "we are
   overloading the meaning of that flag here in RKE2" (`rke2/pkg/rke2/rke2_linux.go:53-57`). Choosing sqlite
   therefore means taking a documented-experimental path to avoid a problem the topology does not have. The
   single-server decision stands either way; **which datastore backs it is the open item**, and embedded etcd is
   the default, the tested path, and the one this file would pick absent direction.
2. **The admin credential's blast radius.** **C44** offers two acceptable shapes and the repo does not say which
   is wanted. R10 makes this urgent rather than eventual: aether5d-dev needs a credential and a SAN before the
   cluster first starts, not after.
3. **Where the etcd snapshots go.** If embedded etcd is taken, nothing in the current plan gets a snapshot off
   yoga; `/persist` survives reboots and nothing else.
4. **Whether the server runs on yoga or in a guest on yoga** (§10, last bullet). Worth an afternoon before any
   Nix is written, because it is the one option that removes six of the fourteen risks rather than mitigating
   them.
