# Kubernetes on this fleet: the constraints

This file records what any Kubernetes distribution and any CNI must satisfy to run on **this** fleet. It
names no candidate, ranks nothing and recommends nothing. It is written to be read *before* anything is
chosen and used *after*, as the thing a proposal is scored against — which only works if it was written
without knowing the answer.

Every hard constraint below carries a `file:line` citation. That is the rule that separates a constraint
from an opinion: if it cannot be traced to something already true in this repo, on these hosts, or in the
pinned nixpkgs, it does not belong in the numbered lists. Things that are merely *preferred* are collected
at the bottom, under their own heading, where they can never be mistaken for requirements.

Where the brief that commissioned this file disagreed with the repo, the repo wins and the disagreement is
recorded in **Discrepancies** at the end.

## The fleet, as the repo actually describes it

| Host | Platform | Role in this work | Availability |
|---|---|---|---|
| yoga | x86_64-linux, NixOS, Gigabyte X870E / AMD | the only always-on Linux machine | continuous |
| skyspy-dev | x86_64-linux, NixOS, Legion 16IRX8H / NVIDIA | intermittent worker | dual-boots Windows (`/etc/nixos/systems/skyspy-dev/default.nix:9-11`) |
| aether5d-dev | aarch64-darwin, nix-darwin, M5 Max | client only, plus an optional Linux VM | continuous, but has no kernel to run a kubelet on |

The three meet over a Tailscale SaaS tailnet with MagicDNS (`tail46cce1.ts.net`), not a shared LAN —
`/etc/nixos/systems/yoga/default.nix:194-221`, `/etc/nixos/systems/skyspy-dev/default.nix:101-108`,
`/etc/nixos/systems/aether5d-dev/default.nix:79-86`. There is no L2 adjacency between any two of them.

## Platform reach

`my.infra` is declared and implemented from `platforms/linux.nix` alone — options at
`platforms/linux.nix:55`, implementation at `platforms/linux.nix:198`. Neither `platforms/darwin.nix` nor
`platforms/common.nix` mentions `infra` anywhere (verified by grep over both files). That is not an
oversight to be fixed; it is the invariant CLAUDE.md calls structural reach, and it is what makes a darwin
host setting a cluster option a hard error instead of a silent no-op.

- **C1.** The cluster domain is Linux-only. It is declared in a file that only `platforms/linux.nix`
  imports, so `my.infra.<cluster>` does not exist on darwin and `aether5d-dev` setting it fails with
  ``The option `my.infra' does not exist`` rather than doing nothing.
  (`platforms/linux.nix:55`, `platforms/linux.nix:198`)
- **C2.** No `pkgs.stdenv.hostPlatform.is*` predicate, and no `mkIf isLinux`, may take part in deciding
  whether a cluster option exists. Reach is decided by which platforms file imports the declaration, full
  stop. (CLAUDE.md, "Platform reach is structural")
- **C3.** No darwin-side stub declaring the option in order to attach a friendlier error. Declaring it
  makes it *exist*, and an `apply = _: throw …` fires only when something reads the option — which on the
  wrong platform nothing does. The result is a silent no-op, strictly worse than the structural behaviour.
  (`platforms/linux.nix:77-90`)
- **C4.** The reach decision must be recorded in `tests/user-option-reach.nix`. `"infra"` is already in
  `topLinuxOnly` with its reason (`tests/user-option-reach.nix:149`) — if the cluster keeps living under
  `my.infra`, that string must be updated to say so; if it gets its own top-level domain, that domain needs
  its own entry. The test enumerates both option trees and fails on any drift, so this is enforced, not
  documented.
- **C5.** `aether5d-dev` gets **client tooling only** — `kubectl`, `k9s`, `helm` — and it arrives as a
  per-user app module under `my/users/apps/dev/<app>`, built with `mkApp`, carrying its own option, and
  imported from `platforms/common.nix` so it exists on both platforms. That is exactly how `devenv`,
  `direnv`, `jq` and the rest already arrive (`platforms/common.nix:139-144`). It must **not** come from
  `my.infra`, because that would make client tooling a Linux-only concept, and it must **not** be added to
  `my/system/base-packages` (`my/system/base-packages/default.nix:17-34`), which is the unconditional base
  CLI set for every machine on the fleet including the container roles.
- **C6.** Installing client tooling must not imply a node. The current module bundles the two — enabling
  the cluster is what installs `kubectl`, `helm` and the distribution package
  (`my/infra/k3s/default.nix:20-25`) — and that shape cannot express "this machine talks to the cluster but
  is not in it", which is precisely what `aether5d-dev` is.

## Topology

- **C7.** Exactly one control-plane member: **yoga**. It is the only machine that is always on, and the
  only one whose absence is not routine.
- **C8.** `skyspy-dev` may only ever be a worker. It dual-boots Windows
  (`/etc/nixos/systems/skyspy-dev/default.nix:9-11`), so its absence is normal operation, not an incident.
  It is not currently a registered tailnet node at all — `tailscale status` from yoga lists five nodes
  (`yoga`, `aether5d-dev`, `iphone181`, `radicle-yoga-seed`, `radicle-yoga-x64-builder`) and `skyspy-dev`
  is not among them, so joining the tailnet is a prerequisite, not an assumption.
- **C9.** **No HA control plane.** Two etcd members give a quorum of `floor(2/2) + 1 = 2`: both must be
  present to serve writes. With `skyspy-dev` as the second member, every trip into Windows takes the API
  server read-write down — not *degraded*, frozen, because a quorum-loss etcd refuses writes and the
  API server has nowhere to persist. A 2-member pair is therefore strictly *less* available than a single
  member: one member has one way to lose quorum, the pair has two. HA becomes arguable at three
  always-on members and this fleet has one.
- **C10.** The single control-plane member's absence must degrade to "running workloads keep running,
  nothing new is scheduled", not "the node is destroyed". Concretely: an agent whose API server has been
  unreachable across several reboots must rejoin when it returns, without a manual step and without a
  re-issued token.
- **C11.** Joining must be declarative and idempotent. An agent that has been in Windows for a week comes
  back with the same identity on the next boot, from configuration alone.
- **C12.** The option surface must be able to say **which server** an agent joins and **with what token**.
  The existing surface cannot: `my/infra/options.nix:9-41` declares only `enable`, `role`, `disableTraefik`,
  `apiPort` and `kubeconfigReadable`. `role = "agent"` is selectable (`my/infra/options.nix:16-20`) and
  unimplementable — there is no server address and no token path anywhere in the module. The underlying
  nixpkgs module does carry both (`services.k3s.serverAddr` and `services.k3s.tokenFile` exist in the
  pinned nixpkgs; verified by evaluating `sys.options.services.k3s` against `flake.lock`'s nixpkgs), so
  this is a gap in the DSL, not in what is available.
- **C13.** `aether5d-dev` is a host client **plus**, if it is to be a node at all, an aarch64 **Linux VM**.
  macOS has no kernel to run a kubelet on; the repo already states the same thing for containers — "there
  is no Linux kernel to run containers on … macOS needs a Linux VM, and the runtime lives inside it"
  (`my/dev/containers/default.nix:1-6`) — and already runs a Lima VM there for Colima
  (`my/dev/containers/default.nix:8-10`). A VM node is therefore not novel on this fleet, but **there is no
  mynixos module that provisions one**: any design that depends on a Mac node must say what creates the VM
  and how it is configured, because today nothing does.
- **C14.** The topology must be expressible as *one always-on server, N intermittent agents*, with N
  allowed to be zero. A design that needs a fixed node count, or that treats a missing node as a fault to
  be alerted on rather than a normal state, does not fit this fleet.

## Networking and MTU

The nodes have no shared broadcast domain. They meet on the tailnet, which is a point-to-point WireGuard
mesh with a **fixed 1280-byte TUN MTU** — observed live on yoga:

```
5: tailscale0: <POINTOPOINT,MULTICAST,NOARP,UP,LOWER_UP> mtu 1280 qdisc fq …
```

while the physical interfaces on the same host are 1500 (`enp13s0`, `wlp12s0`). That 1280 is Tailscale's
own conservative constant, not something derived from the underlay: it does not grow when the LAN is
jumbo-framed and it does not shrink when a peer is behind a tunnel.

- **C15.** No CNI mode that assumes L2 adjacency between nodes. Anything that resolves peers by ARP, that
  needs a shared broadcast domain, or that peers BGP with a top-of-rack switch is disqualified by the
  fleet's shape, not by preference.
- **C16.** **Pod MTU must be set explicitly**, never auto-detected. Every auto-MTU implementation probes
  the interface carrying the default route; on these hosts that is a 1500-byte physical NIC, not
  `tailscale0`. Autodetection therefore overshoots by 270 bytes on every node, and does so without
  reporting anything.
- **C17.** The maximum pod MTU is `1280 − encapsulation overhead`, computed per mode:

  | Node-to-node mode | Overhead | Arithmetic | Max pod MTU |
  |---|---|---|---|
  | none (pods routed natively over the tailnet) | 0 | `1280 − 0` | **1280** |
  | VXLAN over IPv4 (outer IP 20 + UDP 8 + VXLAN 8 + inner Ethernet 14) | 50 | `1280 − 50` | **1230** |
  | Geneve over IPv4, no options (outer IP 20 + UDP 8 + Geneve base 8 + inner Ethernet 14) | 50 | `1280 − 50` | **1230** |
  | Geneve over IPv4 with an *n*-byte option TLV set | `50 + n` | `1280 − 50 − n` | **≤ 1230** |
  | VXLAN or Geneve over IPv6 (outer IP 40 instead of 20) | 70 | `1280 − 70` | **1210** |
  | any of the above plus the CNI's own WireGuard (outer IP 20 + UDP 8 + WG 32) | `+60` | `1280 − 50 − 60` | **1170** |

- **C18.** The number a gate asserts, for a single IPv4 encapsulation with no options and no second
  encryption layer, is **1230**. If the chosen mode is anything else in that table, the asserted number
  moves with it — but a number must be asserted somewhere a test reads, not merely stated here. Geneve
  option bytes count against the same 1280 as everything else; a design that uses them must subtract them.
- **C19.** Anything the cluster runs on top of the pod network that adds its own headers — a service mesh
  sidecar proxy, an encrypted overlay inside the CNI's overlay — subtracts again from the same 1280. The
  budget is not per-layer; it is one budget spent by every layer.
- **C20.** **The failure mode is silent, and the spec exists mainly because of this.** With the pod MTU set
  too high, small packets pass and large ones vanish. The TCP handshake is small, so connections
  establish. DNS is small, so name resolution works. A TLS ClientHello is small, so the session starts. The
  first full-size response is dropped by the encapsulator, and the ICMP "fragmentation needed" it generates
  is addressed to a pod IP inside a network namespace behind NAT and eBPF, where it is routinely lost — so
  path MTU discovery never completes and the sender retransmits the same oversized segment forever. What an
  operator sees is: `kubectl exec` and `kubectl logs` hang after printing nothing, image pulls stall at a
  percentage and time out, large API responses hang while `kubectl get nodes` is instant, and every
  liveness probe passes. Nothing logs an error, on any node, at any layer. A cluster in this state looks
  healthy and is unusable.
- **C21.** Node-to-node ports must be scoped to `tailscale0`, using the idiom the repo already has:
  `networking.firewall.interfaces.tailscale0.allowedTCPPorts` (`my/network/tailscale/default.nix:98`).
  The current module instead opens the API port on **every** interface —
  `networking.firewall.allowedTCPPorts = [ cfg.apiPort ]` (`my/infra/k3s/default.nix:38-41`) — which on
  `skyspy-dev` means the Kubernetes API is offered to whatever café wifi it is attached to.
- **C22.** `trustedInterfaces` must follow from the CNI actually in use. `my/infra/k3s/default.nix:40`
  hardcodes `cni0` and `flannel.1`, which are one specific CNI's interface names. Under any other CNI those
  interfaces never appear, the real ones are untrusted, and pod traffic is dropped by the host firewall
  with nothing in any log naming the cause.
- **C23.** Nodes address each other by **MagicDNS name**, not by tailnet IP. mynixos already pins the
  tailnet name to `networking.hostName` on every start (`my/network/tailscale/default.nix:80-83`, and the
  comment above it records a real incident where a renamed machine kept its old tailnet identity silently).
  An IP is what changes when a node is rebuilt; the name is what does not.
- **C24.** The kubelet's node IP must be settable to the node's tailnet address. A CNI or distribution that
  insists on the interface carrying the default route will pick the 1500-byte physical NIC, which no other
  node can reach.
- **C25.** Pod and service CIDRs must not overlap **100.64.0.0/10**. That is the CGNAT range Tailscale
  allocates node addresses from — every node on this tailnet has one (`100.97.96.49` yoga,
  `100.103.172.43` aether5d-dev, and so on, from `tailscale status`) — and an overlap makes the tailnet
  unreachable from inside any pod, including the CNI's own agents.

## Secrets

The cluster join token is key material: it authenticates a new node into the cluster and, on most
distributions, is also the seed for the cluster's own CA-adjacent bootstrap data. It is subject to the
policy this repo already enforces for every other secret.

- **C26.** The join token is delivered by **sops-nix**, and the sops file it comes from is a **runtime
  path** — a quoted string such as `"/persist/etc/sops/secrets.yaml"`. `my.secrets.allowSecretsInStore`
  defaults to `false` and asserts on both `defaultSopsFile` and every `sops.secrets.<name>.sopsFile`
  (`my/secrets/options.nix:19-42`, `my/secrets/default.nix:65-82`). The policy is tested in both
  directions — a store path is rejected, a runtime path is accepted, a per-secret override is caught even
  when the default is clean (`tests/secrets-store-policy.nix:51-73`).
- **C27.** The token must **never** reach `/nix/store`. The store is world-readable (`drwxrwxr-t`) and
  permanent: anything placed there is readable by every user and every process on the host, cannot be
  removed by deleting the source, and is carried along by `nix copy`. Encryption is not a defence against
  publication — it exposes the ciphertext, the recipient list and the rotation history, and makes any
  future compromise of a recipient key retroactive over every version ever built
  (`my/secrets/options.nix:22-41`, `my/secrets/default.nix:18-41`).
- **C28.** The shape the policy exists to block is indirect: interpolating a flake input,
  `"${someInput}/secrets.yaml"`, reads as a reference to one file and copies the whole **directory** it
  sits in, publishing whatever else is beside it with nothing in the configuration naming it. This is not
  hypothetical on this fleet — it is how a seed's plaintext node key ended up world-readable in two store
  paths (`/etc/nixos/systems/yoga/default.nix:144-160`).
- **C29.** The token must be passed to the distribution through a **file-valued** option, never a
  string-valued one. A string option is rendered into the systemd unit, and the unit is a store path — so a
  `token = "…"` reintroduces exactly the exposure C27 forbids, by a route the sops assertions cannot see
  (they check `sops.secrets.*.sopsFile`, not arbitrary strings).
- **C30.** The decrypted token file is root-owned, mode `0400`. That is the repo's existing idiom for key
  material: `my/dev/remote-builders/default.nix:34` (the remote-builder ssh key) and
  `my/infra/radicle/default.nix:136-139` (the radicle node key), both with the same reasoning — systemd
  reads credential sources as root before `User=` drops privileges, so the service account never needs and
  never gets direct read access.
- **C31.** A node that runs inside a **rootless container** cannot use sops-nix at all.
  `sops-install-secrets` mounts a ramfs, which needs `CAP_SYS_ADMIN`; a rootless container has not got it,
  and merely *declaring* a secret is enough to make activation fail
  (`my/infra/radicle/default.nix:129-139`). The fleet's existing answer is to decrypt on the host and
  bind-mount the plaintext in (`/etc/nixos/systems/yoga/default.nix:316-323`). Any containerised node
  inherits this constraint.
- **C32.** `skyspy-dev` has **no `my.secrets` block at all** (verified by grep over
  `/etc/nixos/systems/skyspy-dev/default.nix`) — no `defaultSopsFile`, no `ageKeyFile`. yoga has both, at
  runtime paths on `/persist` (`/etc/nixos/systems/yoga/default.nix:161-165`). Wiring sops on `skyspy-dev`
  is therefore a prerequisite of it joining, and that wiring has to name a path that exists on a machine
  with no dedicated `/persist` partition (`/etc/nixos/systems/skyspy-dev/default.nix:130-132`).

## Persistence

yoga's root filesystem is a **16 GB tmpfs** (`/etc/nixos/systems/yoga/disko.nix:4-10`) and `/persist` is a
dedicated partition (`/etc/nixos/systems/yoga/disko.nix:68-75`) mounted `neededForBoot`
(`my/storage/impermanence/impermanence.nix:36-38`). Anything not named in
`environment.persistence."/persist"` is gone at every reboot. The base system list is only `/etc/nixos`,
`/var/lib/nixos`, `/var/lib/systemd` and `/var/log`
(`my/storage/impermanence/impermanence.nix:102-107`); everything else is contributed by feature modules
through `my.system.persistence.features.systemDirectories`
(`my/storage/impermanence/impermanence.nix:109`).

**The existing cluster module contributes nothing.** The only persistence declaration in `my/infra` is in
the GitHub-runner module (`my/infra/github-runner/default.nix:494-500`), so
`my.infra.k3s.enable = true` on yoga *today* produces a cluster that destroys its own identity on every
reboot, and the directories that would save it are declared by a different, unrelated feature.

Directory by directory, what it holds and what losing it costs:

| Directory | Holds | Cost of losing it |
|---|---|---|
| `/var/lib/rancher/<dist>` (server) | the datastore (etcd or its embedded equivalent), the cluster CA and its private key, the node token, bootstrap data | **Node identity destroyed, and the cluster with it.** A regenerated CA is a *different* CA: every agent's stored credential is invalid, every issued ServiceAccount token is invalid, every kubeconfig in existence is invalid. This is a new cluster wearing the old one's hostname. |
| `/var/lib/rancher/<dist>` (agent) | the agent's server-issued credentials and its copy of the CA bundle | **Node identity destroyed.** The agent re-bootstraps as a new node; the old node object lingers `NotReady` until something reaps it. |
| `/var/lib/kubelet` | the kubelet's client certificate and key, `pods/` volume mounts, plugin and device-plugin sockets, `cpu_manager_state`, the pod-resources checkpoint | **Node identity destroyed**, plus silent data loss: a pod with a `hostPath` or local volume comes back with an empty mount and no error. Every boot also files a fresh CSR, so any approval policy is re-satisfied on every reboot and stale certs accumulate. |
| container image store (`…/agent/containerd` for a bundled runtime, `/var/lib/containerd` for a standalone one) | image content and snapshots | Regenerates — images can be re-pulled — but **not harmlessly on yoga**: it regenerates into the 16 GB tmpfs root, so every image pulled after a reboot is resident RAM competing with the 28 GB `/tmp` and 16 GB `/tmp/gpu-workdir` tmpfs on the same machine (`/etc/nixos/systems/yoga/disko.nix:11-27`). That is a memory-exhaustion path, not a slow start. |
| `/var/lib/cni` and `/var/lib/cni/networks` | IPAM allocation records | **Regenerates harmlessly across a clean boot** (no pods, no allocations to remember) and **not harmlessly otherwise**: the allocation store is the only record of which pod IP is in use, so losing it under running pods hands out duplicates. |
| `/etc/rancher/<dist>` | the server config file, the generated admin kubeconfig, registry configuration | Regenerates *from the CA* — so harmless if the CA is persisted, and a fresh admin kubeconfig on every boot if it is not. Note that `/etc` is **not** persisted on this fleet except `/etc/nixos` (`my/storage/impermanence/impermanence.nix:102-107`), so this needs declaring either way if the config file is written at runtime rather than generated by Nix. |
| the CNI's own state (an eBPF/agent state directory; a per-node encryption key if the CNI encrypts) | node-local CNI identity and cached programme state | Programme state regenerates harmlessly. **A per-node encryption key does not** — a regenerated key makes every peer's record of this node stale, which is node identity in the same sense as the rows above. |
| `/var/log` | cluster and kubelet logs | Already persisted (`my/storage/impermanence/impermanence.nix:106`); no action needed. |

- **C33.** Every directory above that is not already covered must be declared by the cluster module itself,
  through `my.system.persistence.features.systemDirectories` — the mechanism for a system-level feature with
  no `apps.*` option to carry paths (CLAUDE.md, "Persistence aggregation"). It must **not** be pushed into a
  host file's `extraSystemDirectories`: a host must not have to know which directories a cluster needs.
- **C34.** Declaring a directory another module already persists is safe and expected. The system list is
  `unique`d (`my/storage/impermanence/impermanence.nix:102`) precisely so two features can both be right
  about needing the same path — `/var/lib/containers` is already claimed by the developer podman feature
  (`my/dev/development/default.nix:186-193`) and would be claimed again by a container runtime here.
  Without `unique`, impermanence rejects the repeat with a build error that names the directory and nothing
  about who asked for it.
- **C35.** `my.system.persistence` is declared on Linux only. A cross-platform module contributes to it from
  a Linux-only sibling, never directly (`my/storage/impermanence/options.nix:1-13`). For a Linux-only
  cluster domain this is automatic, but it constrains any shared helper the domain grows.
- **C36.** The persistence declarations must be correct on **both** Linux hosts, even though only yoga
  wipes. `skyspy-dev` enables `my.storage.impermanence` (`/etc/nixos/systems/skyspy-dev/default.nix:130-132`)
  while its root is a plain ext4 that nothing wipes
  (`/etc/nixos/systems/skyspy-dev/filesystem.nix:6-9`) — so a missing declaration is invisible there and
  fatal on yoga. Correctness must not depend on which host happens to have a tmpfs root.
- **C37.** Anything the cluster needs before `local-fs.target` must live on `/persist`, which is
  `neededForBoot` (`my/storage/impermanence/impermanence.nix:36-38`). A credential or datastore reached
  through a path that is not is a boot-order bug that appears only on the impermanent host.

## Mixed architecture

yoga and `skyspy-dev` are `x86_64-linux`. A Mac VM node would be `aarch64-linux`. Nothing about the
cluster may assume one architecture.

- **C38.** Every image deployed to the cluster must exist for **both** `linux/amd64` and `linux/arm64` — as
  a manifest list, or as per-architecture tags selected by a node selector. A workload that exists for one
  architecture only must be pinned to nodes of that architecture explicitly, not left to chance.
- **C39.** **An architecture mismatch fails at pod start, not at evaluation.** Nix type-checks nothing
  about a container image reference; `nix flake check` will pass, both host closures will build, and the
  failure surfaces as `exec format error` or an `ImagePullBackOff` on a manifest with no matching platform
  — at runtime, on the node, possibly weeks later. Any gate that intends to catch this must inspect
  manifests; no amount of module-system rigour will.
- **C40.** A candidate's own bundled images are **per-architecture**, and the selection must be a function
  of the node's `nixpkgs.hostPlatform`, never a constant. Verified against the pinned nixpkgs: a
  distribution that ships airgap image bundles exposes them as arch-suffixed attributes —
  `images-core-linux-amd64-tar-zst` and `images-core-linux-arm64-tar-zst`, with the same `amd64`/`arm64`
  pairing repeated for every bundled component (calico, canal, cilium, flannel, multus, traefik, …). A
  module that names one of those attributes literally produces a system that cannot be built for the other
  architecture, and the error arrives as a missing attribute at eval time on the *second* host, not on the
  first.
- **C41.** There is **no fast native `aarch64-linux` build path on this fleet**, and any design that needs
  one must say where it comes from. Today: yoga can build `aarch64-linux` only through qemu binfmt
  (`boot.binfmt.emulatedSystems = [ "aarch64-linux" ]`, `my/dev/development/default.nix:171-173`), which is
  slow and gated behind the developer feature; and `aether5d-dev` is an `aarch64-**darwin**` remote builder
  (`my/dev/remote-builders/options-linux.nix:37-41`,
  `/etc/nixos/systems/aether5d-dev/default.nix:63-74`, currently gated shut), which does not provide
  `aarch64-linux` at all.
- **C42.** The architecture must not leak into the option surface as a host-set constant. A host already
  states its architecture once, through its hardware profile (CLAUDE.md, "Hardware profiles"); a cluster
  option that asks for it again is two sources for one fact, and they will disagree.

## Security posture

- **C43.** **The kubeconfig must not be world-readable.** The current module makes it exactly that: a
  oneshot unit waits for the file and runs `chmod 644 /etc/rancher/k3s/k3s.yaml`
  (`my/infra/k3s/default.nix:44-58`, the `chmod` at `my/infra/k3s/default.nix:56`), driven by
  `kubeconfigReadable`, which **defaults to `true`** (`my/infra/options.nix:34-38`). The same code appears
  a second time in the runner module (`my/infra/github-runner/default.nix:385-399`). That file embeds the
  cluster-admin client certificate *and its private key*: mode 644 grants full, unauthenticated,
  unaudited cluster-admin to every local account and every process on the host — a browser, a language
  server, a CI runner's job, anything.
- **C44.** An acceptable mechanism looks like one of these, and nothing looser:
  - the admin kubeconfig stays root-owned at `0600`, and interactive users get a **separate, scoped
    credential** — a client certificate or a ServiceAccount token bound to a Role rather than
    `cluster-admin` — delivered as a sops secret at mode `0400` owned by that user
    (`my/dev/remote-builders/default.nix:34`, `my/infra/radicle/default.nix:136-139`); or
  - the file is `0640` root-owned with a **dedicated group** whose membership is declared, the way the
    repo already scopes a service state directory at `0750`
    (`my/network/monitoring/default.nix:27`).

  What is not acceptable: any mode with a world bit, and any arrangement that makes `cluster-admin` the
  default identity of an interactive login session.
- **C45.** `environment.variables.KUBECONFIG` must not be set fleet-wide to the admin file. The current
  module sets it for every user on the host (`my/infra/k3s/default.nix:27-29`, again at
  `my/infra/github-runner/default.nix:321-324`), which is what turns C43's file mode into every shell's
  default credential. A per-user kubeconfig is per-user (home-manager), and pointing at it is then not
  itself a grant.
- **C46.** The API port must not be open on every interface — see **C21**. Restating it here because it is
  a security property and not only a networking one: on `skyspy-dev` the current rule offers the
  Kubernetes API to any network the laptop attaches to.
- **C47.** yoga runs secure boot with lanzaboote (`/etc/nixos/systems/yoga/default.nix:121-123`). Anything
  requiring an **out-of-tree, unsigned kernel module** is disqualified on that host. eBPF programmes are
  not affected — they are loaded, not module-signed — but a CNI or runtime that ships a `.ko` is.
- **C48.** `skyspy-dev` pins `linuxPackages_6_12` for the NVIDIA open modules
  (`/etc/nixos/systems/skyspy-dev/default.nix:202-209`). Any kernel-version floor — an eBPF helper, a
  cgroup v2 behaviour, an nftables feature — must be satisfied by **6.12**, not merely by whatever yoga
  happens to run.
- **C49.** A node must not require the operator to be in a root-equivalent group on the host. That is the
  fleet's stated reason for preferring rootless podman over docker (CLAUDE.md, `my.dev`; and
  `my/dev/containers/default.nix:21-27`), and adding a cluster is not a reason to reintroduce one.
- **C50.** No unpinned remote fetch during activation. The existing runner module `kubectl apply -f`s a
  GitHub release URL and `helm repo add`s an upstream chart repository from a systemd unit
  (`my/infra/github-runner/default.nix:425-442`), which makes every boot depend on third-party
  availability and on whatever content is behind those URLs that day. Cluster bootstrap content must be
  pinned — by digest, by a nixpkgs attribute, or by a vendored manifest.

## Repo gates

Confirmed against CLAUDE.md, `flake.nix`, `treefmt.nix` and the CI workflow. A change to the cluster domain
passes all of these before it is proposed.

- **C51.** `nix fmt` leaves the tree unchanged. treefmt runs `nixpkgs-fmt`, `shfmt`, `shellcheck` and
  `yamlfmt` (`treefmt.nix:5-28`), surfaced as `checks.<system>.formatting` (`flake.nix:330`).
- **C52.** **statix and deadnix are the same gate as `nix fmt`**, not separate ones: both are treefmt
  programs (`treefmt.nix:13-20`), and they were deliberately folded in so that `nix fmt` locally and CI
  cannot disagree about whether the tree is clean (`.github/workflows/ci-and-release.yml:53-57`). Running
  them separately is fine; expecting a separate CI job is stale.
- **C53.** `nix flake check` passes. It is declared for `x86_64-linux` and `aarch64-linux` only
  (`flake.nix:114-120`) and it runs the whole check suite plus `checks.pre-commit`, the git-hooks bundle
  (`flake.nix:330-332`, `flake.nix:147-158`). CI runs exactly this (`.github/workflows/ci-and-release.yml:58-59`).
- **C54.** `tests/user-option-reach.nix` passes — which it will only if **C4** was honoured.
- **C55.** A **booting VM test** covers the cluster. The VM tests live under `tests`, not `checks`, so
  `nix flake check` stays light and KVM-free, and are run on demand with
  `nix build .#tests.<system>.<name> -L` (`flake.nix:349-380`). The shape to copy is
  `tests/vm-radicle.nix`: two VMs on an isolated network, which is what makes "private network" true by
  construction rather than by configuration. For a cluster the assertions are a server coming up, a second
  node joining, and — per **C18** — the pod MTU actually in effect on the node.
- **C56.** **Both host closures build.** This is a consumer-flake gate, not a mynixos one — mynixos has no
  hosts. It is `nix build /etc/nixos#nixosConfigurations.yoga.config.system.build.toplevel` and the same for
  `skyspy-dev` (`/etc/nixos/flake.nix:91-99`). The in-repo `rebuild-system` / `build-system` /
  `test-system` scripts build only the machine they run on
  (`my/system/scripts/default.nix:239-256`), so nothing automates this: it is an explicit command, and CI
  does not enforce it.
- **C57.** `scripts/module-coverage.sh --lcov` runs in CI (`.github/workflows/ci-and-release.yml:72-73`),
  so a new module directory with no test shows up as uncovered rather than passing silently.
- **C58.** The MTU number from **C18** must be asserted by something a gate runs — the VM test of **C55**
  is the natural home. Prose in this file is not a gate.

## Out of scope

This work explicitly does **not**:

- Choose or evaluate a distribution or a CNI. That is the next phase, and it is scored against this file.
- Migrate, preserve or replicate anything from the existing `my/infra/k3s` and `my/infra/github-runner`
  modules. Their current state is cited here as evidence of constraints, not as a baseline to be kept
  compatible with.
- Re-enable GitHub ARC. It is off on both hosts today
  (`/etc/nixos/systems/yoga/default.nix:173-178`, `/etc/nixos/systems/skyspy-dev/default.nix:75`), and
  bringing it back is its own decision with its own constraints (notably **C50**).
- Touch the Radicle forge. It runs as rootless-podman roles that are machines in their own right
  (`/etc/nixos/systems/yoga/default.nix:289-374`, `docs/radicle-containers.md`) and it is not a Kubernetes
  workload. Nothing here proposes moving it.
- Provision a Linux VM on `aether5d-dev`. **C13** records that a Mac node needs one and that no module
  creates one; writing that module is separate work.
- Define ingress, TLS termination, certificate issuance, observability, GPU scheduling, storage classes or
  CSI drivers. None of them is a constraint on the *choice*; all of them are downstream of it.
- Add `skyspy-dev` to the tailnet, or add `my.secrets` wiring to it. **C8** and **C32** record that both are
  prerequisites; doing them is not part of writing this spec.
- Change `my.secrets`, impermanence, or the Tailscale modules. This work consumes their existing contracts;
  if one of them turns out to be insufficient, that is a finding to report, not a change to make silently.

## Preferences, not requirements

Nothing in this section is citable to the repo, and nothing in it may be used to disqualify a candidate.
It is recorded only so that a later reader can tell taste from constraint.

- Fewer moving parts over more. A distribution whose control plane is one process is easier to reason about
  on a single always-on desktop than one assembled from several.
- A CNI whose data path can be inspected with tools already on these hosts.
- Configuration expressed as mynixos options rather than as YAML applied by a `systemd` oneshot — the
  existing module's `helm upgrade --install` from an activation unit
  (`my/infra/github-runner/default.nix:84-94`) is the pattern this preference reacts against.
- Bootstrap that is idempotent and re-runnable, rather than guarded by a `ConditionPathExists` marker file
  (`my/infra/github-runner/default.nix:406-408`), which makes "has this already run?" a property of a
  file on a tmpfs rather than of the cluster.
- Not naming a distribution's bundled components in the mynixos option surface. `disableTraefik`
  (`my/infra/options.nix:22-26`) is a one-vendor concept in a vendor-neutral namespace.
- One cluster rather than several.
- Keeping the domain name `my.infra.<something>` rather than promoting the cluster to a new top-level
  domain, so the existing reach entry keeps meaning what it says.

## Discrepancies found while writing this

Recorded because the brief that commissioned this file asserted each of them, and the repo says otherwise.

1. **yoga does not run GitHub ARC on k3s.** `my.infra.k3s` is never set in
   `/etc/nixos/systems/yoga/default.nix` (so it takes the `false` default) and
   `github-runner.enable = false` (`/etc/nixos/systems/yoga/default.nix:173-178`). The stack is code that
   exists, not a system that runs. What *is* live on yoga is the Radicle forge as rootless-podman roles
   (`/etc/nixos/systems/yoga/default.nix:289-374`), confirmed by `tailscale status` listing
   `radicle-yoga-seed` and `radicle-yoga-x64-builder` as nodes.
2. **`skyspy-dev` does run impermanence** — `storage.impermanence.enable = true`
   (`/etc/nixos/systems/skyspy-dev/default.nix:130-132`). Its root is a plain ext4
   (`/etc/nixos/systems/skyspy-dev/filesystem.nix:6-9`), so nothing is wiped and the *effect* the brief
   describes is right; the mechanism is not, and **C36** depends on the difference.
3. **`skyspy-dev` is not currently on the tailnet.** `tailscale status` from yoga lists five nodes and
   `skyspy-dev` is not one of them.
4. **`services.k3s.extraFlags` is not the module's bug.** In the pinned nixpkgs its type is
   `string or list of string`, so the `toString` at `my/infra/k3s/default.nix:14-16` is valid. The module's
   real defects are the ones cited above: no server address or token (**C12**), no persistence (**C33**),
   a 644 kubeconfig (**C43**), an API port open on every interface (**C21**), and hardcoded CNI interface
   names (**C22**).
5. **CLAUDE.md is stale about `platform = "oci"`.** It documents a third mkSystem platform; `lib/mkSystem.nix:30-36`
   records that the value was removed and that a container image is now `system.build.image`, an output of
   any Linux system. This changes no constraint here, but anything that reads CLAUDE.md for the emitter
   shape will be wrong.

## Open questions

These could not be settled from the repo and need an answer before the next phase can be scored properly.

- Is `skyspy-dev` intended to rejoin the tailnet at all? Every topology constraint that involves it assumes
  yes, and nothing in the repo says so.
- Is a Mac VM node wanted in this phase, or is `aether5d-dev` client-only for now? The answer decides
  whether **C38**–**C41** are live requirements or forward-looking ones.
- Is the cluster single-stack IPv4 or dual-stack? `my.network.ipv6` privacy extensions are on fleet-wide,
  and the answer selects which row of the **C17** table the asserted number comes from.
- Must the cluster survive a yoga rebuild that changes its tailnet IP? **C23** assumes yes and requires
  MagicDNS everywhere; if a static tailnet IP is acceptable, that constraint relaxes.
- What is the intended blast radius of the admin credential — is there meant to be a non-admin identity for
  interactive use, or is `cluster-admin`-for-the-operator acceptable behind a `0600` file? **C44** offers
  both shapes because the repo does not say which is wanted.

## Answers to the open questions (decided 2026-09-05)

The five questions above were put to the fleet owner and answered. They are recorded here rather than in a
conversation because this file is what later phases are scored against, and an unrecorded decision is one the
next reader has to re-derive.

- **Single-stack IPv4.** The asserted pod MTU is therefore **1230** — the `VXLAN over IPv4` /
  `Geneve over IPv4, no options` row of the **C17** table, with no second encryption layer. `my.network.ipv6`
  privacy extensions being on fleet-wide does not by itself force IPv6 encapsulation for node-to-node
  traffic. **C18** is settled: 1230 is the number a gate asserts, and any design that moves it must move the
  assertion with it and say why.
- **No CNI-level encryption.** The tailnet already carries this traffic over WireGuard. A second layer would
  be double-encrypt and would spend 60 more bytes of the same 1280 budget (**C19**), taking the pod MTU to
  1170 for no confidentiality that is not already there.
- **`aether5d-dev` is client-only for this run.** It gets kubectl/k9s/helm on the host through the per-user
  apps tree, per **C5**. The aarch64 Linux VM node is deferred to a follow-up, so **C38**–**C41**
  (mixed architecture) are **forward-looking, not live requirements** for this run — the cluster is
  single-arch x86_64 until that VM lands. They stay in this document because the follow-up will need them
  and because a constraint deleted is a constraint rediscovered the hard way.
- **`skyspy-dev` stays in scope as the agent node.** Its current absence from the tailnet is treated as
  temporary; every topology constraint involving it stands as written.

## Correction notice

Five assertions in the brief that commissioned this file were wrong and are corrected in
**Discrepancies found while writing this** above. The two that change what this work is:

1. **yoga runs no cluster today.** `github-runner.enable = false` and `my.infra.k3s` is never set, so the
   existing stack is code that exists rather than a system that runs. This deploy tears nothing down. What
   *is* live on yoga is the Radicle forge as rootless-podman roles, which must survive untouched.
2. **`platform = "oci"` no longer exists** (`lib/mkSystem.nix:30-36`). The platform enum is the operating
   system and only that; "adding a format is adding an output, never a platform", and `system.build.vm`
   already exists as an output of any Linux system. CLAUDE.md still documents the removed value and is
   stale — anything that reads it for the emitter shape will be wrong.

## Amendment: how the domain declares persistence (decided 2026-09-05)

**C33 says persistence must come from the cluster module. This says what shape that takes**, because "the
module declares it" admits two shapes and only one of them is the idiom this repo already uses.

The pattern is the forge's (`my/infra/radicle/default.nix:399-402`): **one contribution point in the
domain's implementation, composed with `optionals` keyed on each sub-service's own enable flag.**

```nix
my.system.persistence.features.systemDirectories =
  [ "/var/lib/radicle" ]
  ++ optionals cfg.ci.enable     [ "/var/lib/radicle-ci" "/var/log/radicle-ci" ]
  ++ optionals cfg.mirror.enable [ "/var/lib/radicle-mirror" ];
```

- **C59.** The cluster domain declares its persistence the same way: a single
  `my.system.persistence.features.systemDirectories` expression in the domain's implementation, whose terms
  are gated per sub-service and per role. A directory is persisted **iff** the thing that owns it is
  enabled. Never an unconditional flat list — that persists directories for services which are off, and an
  empty persisted directory is indistinguishable from a service that failed to write.
- **C60.** Role-gate what genuinely differs. An agent has no datastore, no cluster CA and no node token, so
  anything server-only belongs behind `optionals (cfg.role == "server")`. Paths that exist under both roles
  are declared once, unconditionally within the domain.
- **C61.** **The container image store must be persisted**, and it is not a separate declaration: under RKE2
  it lives beneath `/var/lib/rancher/rke2/agent/`, so persisting the distribution's state root covers it.
  This is the constraint the Persistence table's "memory-exhaustion path" row exists for, and the repo
  already knows the shape of this bug — `my/dev/development/default.nix:186-193` persists rootless podman's
  store for exactly the same reason, in its own words: "on an impermanent host it is the difference between
  keeping images and re-pulling them every boot". `/persist` has ~3 TB free, so the storage cost is not a
  consideration; the RAM cost of *not* doing it is.
- **C62.** **`my/infra/github-runner/default.nix:494-500` must stop declaring cluster persistence.** It
  currently writes `/var/lib/rancher`, `/var/lib/kubelet` and `/var/lib/cni` as an unconditional flat list —
  a module persisting state for a cluster it does not own, which is the same layering inversion as its
  duplicated `services.k3s` block. Both move in the same milestone. Note the existing list is also
  incomplete (no `/etc/rancher`) and undifferentiated (no role gating), so it must be replaced by the
  domain's declaration rather than relocated verbatim.
- **C63.** A CNI that keeps node-local state declares it from the same expression, gated on that CNI being
  the selected one — `optionals (cfg.cni == "…")`. The exact paths come from the configuration reference,
  read out of the upstream sources; they are not to be guessed here.

## Amendment: findings from the upstream sweep (2026-09-05)

Eight parallel researchers read the cloned upstreams; eight high-impact claims went to adversarial
verification and **seven were refuted or materially corrected**. What survived, and what the corrections
change, is recorded here because several of them contradict this document's own earlier text.

### C64 — NetworkManager: enabling RKE2 breaks the live forge [VERIFIED]

`my/system/core/default.nix:161` writes `/etc/NetworkManager/conf.d/99-unmanaged-cni.conf`, whose
`unmanaged-devices` key excludes `cni*;flannel*;veth*;docker*;podman*;br-*` — the `podman*` and `br-*` entries
are what keep NetworkManager's hands off the **running Radicle forge**. The nixpkgs rke2 module writes its own
`NetworkManager/conf.d/rke2-canal.conf` setting the *same key*. NetworkManager reads `conf.d` in lexical order
and a later file overrides an earlier one for the same key; `'9'` is 0x39 and `'r'` is 0x72, so
**`rke2-canal.conf` sorts last and wins**, silently dropping the podman/docker/bridge exclusions.

- The cluster module must `mkForce` the nixpkgs file off (`environment.etc."NetworkManager/conf.d/rke2-canal.conf".enable = false`)
  and let exactly one file own the key. This is required **whatever CNI is chosen** — it is not a Cilium cost.
- That one file must also carry the selected CNI's interfaces. For Cilium: `cilium_host`, `cilium_net`,
  `cilium_vxlan`, `lxc*`.
- There are currently **three** writers of this key — `my/system/core/default.nix:161`,
  `my/infra/k3s/default.nix:33` and `my/infra/github-runner/default.nix:329`. Consolidate to one owner.

### C65 — the ordering fix is the root cause; the MTU pin is insurance [VERIFIED mechanism]

The real defect is not a number, it is that RKE2 can start before the tailnet exists. `--node-ip`, the
apiserver advertise address, kubelet registration and the agent's `serverAddr` all depend on `tailscale0`
being up and addressed.

- Order the unit: `systemd.services.rke2-server.after = [ "tailscaled.service" ]` plus an `ExecStartPre`
  that waits for the tailnet address. This closes the window for *everything* tailnet-dependent, not just MTU.
- **This supersedes C16's framing.** C16 said pod MTU "must never be auto-detected" because autodetection
  would probe a 1500-byte NIC. That is wrong for Cilium: `pkg/mtu/manager.go` takes `min(dev.MTU)` over
  selected devices and scans all routing tables (`RT_TABLE_UNSPEC`), so `tailscale0` **is** selected and it
  converges on 1280 by itself. Pinning is still right, but as a *determinism* fix across three
  differently-shaped machines — not because autodetection computes the wrong answer.

### C66 — the MTU knob is 1280, and 1230 is what it yields [VERIFIED]

The Cilium value and the asserted value are **different numbers for the same configuration**, and confusing
them costs another 50 bytes.

- Set `MTU: 1280` in the `rke2-cilium` values — this is the *device* MTU.
- With VXLAN that yields a pod **route** MTU of **1230** and an outer packet of exactly 1280.
- **1230 remains the number a test asserts** (C18), but the knob that produces it reads 1280. Setting the
  knob to 1230 would yield a 1180 route MTU.
- 1280 is a hard floor: it is the IPv6 minimum MTU. Single-stack IPv4 was chosen, so this does not bite —
  but it is why the pod route MTU may not be lowered further.

### C67 — C20's "silent black hole" is wrong for this stack [REFUTED, corrected]

C20 says an over-large pod MTU produces a silent hang that no layer logs. For **this** combination that is
not what happens, and the correction matters because C20 is the stated reason this document exists.

Cilium sets neither `DF` on `cilium_vxlan` nor `BPF_F_DONT_FRAGMENT`, and `skb_tunnel_check_pmtu` neither
drops nor ICMPs for a non-bridge-port device. An oversized outer packet is **IP-fragmented by the local
kernel** to ≤1280, carried by Tailscale and reassembled at the peer. Additionally RKE2's chart ships
`pmtuDiscovery.packetizationLayerPMTUDMode: "blackhole"` and cilium-cni sets `tcp_mtu_probing=1` in every pod
netns — RFC 4821 PLPMTUD, which recovers TCP without ICMP.

- The real symptom is **throughput collapse, reassembly pressure and loss amplification**, not a hang. UDP
  and QUIC do not get the PLPMTUD rescue.
- The MTU assertion in the VM test therefore stays, but it must be understood as guarding a **performance
  and correctness cliff**, not an outage. A test that only checks "does a large payload arrive" may pass on a
  misconfigured cluster, because fragmentation makes it arrive. Assert the pod's route MTU directly as well.

### C68 — kubeProxyReplacement is NOT RKE2's default, and must stay off [VERIFIED]

RKE2's `rke2-cilium` fork never sets `kubeProxyReplacement`, so upstream's `false` stands, socket-LB is off,
and RKE2 keeps deploying its own kube-proxy.

- **Do not enable KPR.** It is what would attach 13 BPF programs at the cgroup2 root, above every process on
  yoga including the rootless-podman forge. Hubble — the reason this CNI was chosen — needs none of it.
- Two host mutations happen regardless of KPR: an init container nsenters PID 1's namespaces to mount a
  second cgroup2 at `/run/cilium/cgroupv2`, and `sysctlfix` writes `/etc/sysctl.d/99-zzz-override_cilium.conf`
  and restarts systemd-sysctl. On a tmpfs root both are ephemeral by construction. The sysctl write is
  removable at the root cause: `sysctlfix.enabled=false` plus the same rules in `boot.kernel.sysctl`.

### C69 — Hubble ships DISABLED in RKE2's fork [VERIFIED]

`hubble.enabled: false` in the Rancher chart. Enabling it is a `HelmChartConfig` through
`services.rke2.manifests` — which is the same mechanism as every other setting here, so it costs nothing new,
but it does mean **Cilium alone buys no observability at all** until that config lands. This is why Hubble is
a milestone rather than an assumed side effect.

### C70 — flannel is disqualified; the field is Cilium vs canal vs calico [VERIFIED]

RKE2's flannel chart patch deletes the upstream `kube-network-policies` sidecar, its values and its RBAC.
NetworkPolicy objects are accepted by the API server and **enforce nothing**. Silently-inert security policy
is worse than none.

Also settled, so nobody re-opens them: Weave archived 2024-06; kindnet archived 2025-10; Antrea does not start
on NixOS unmodified (its `install_cni` greps `/lib/modules/$(uname -r)/modules.builtin` under `set -euo
pipefail`, and `/lib` does not exist); kube-router ships no Helm chart, so it cannot use the declarative
manifest path at all; Kube-OVN plants a second stateful control plane on the node deliberately kept simple.

### C71 — observability is not a Cilium monopoly, but depth is [VERIFIED]

Calico OSS 3.30+ ships Goldmane (flow-log API) and Whisker (flow UI); RKE2 merely flips them off in its fork
and a `HelmChartConfig` turns them back on, with multi-arch images already in the airgap set. What Hubble adds
over that: **L7/DNS visibility, per-flow eBPF drop reasons, the service map, the `hubble observe` CLI, and
Prometheus flow metrics.** Canal, being a manifest install with no tigera-operator, has no supported path to
either.

### C72 — Cilium leaves the only CI-tested NixOS path [VERIFIED]

nixpkgs' own `nixos/tests/rancher/` suite exercises **canal only**, on both architectures, and pins the
flannel interface through exactly the `services.rke2.manifests` HelmChartConfig mechanism this fleet needs.
Choosing Cilium means the dataplane runs on a configuration nobody CI-tests on NixOS — which makes
`tests/vm-rke2-cluster.nix` **load-bearing rather than diligent**, and is an argument for building it before
the implementation, as planned.

### C73 — reverse-path filtering stays strict; relax only on evidence [DECIDED]

`checkReversePath` is unset throughout mynixos and both host files, so NixOS's default of `true` applies and
the `nixos-fw-rpfilter` mangle chain with a DROP default is live. Note this is a **different mechanism** from
`net.ipv4.conf.*.rp_filter`, which is already `0` on yoga — setting the sysctl does nothing to the iptables
rule, and Cilium's `sysctlfix` only touches the sysctl.

- **Strict filtering stays on.** `checkReversePath` is not to be set to `false` or `"loose"` as a precaution.
- `networking.firewall.logReversePathDrops = true` on first bring-up, **before** anything else is changed, so
  the question is answered by observation rather than by copying someone else's workaround.
- **`toFQDNs` egress policy is out of scope for this run.** It is the only capability that reportedly forces
  the relaxation, its consumer (constraining ARC runners) does not exist yet, and Hubble — the reason this CNI
  was chosen — needs neither it nor kube-proxy-replacement.
- If drops are observed, the fix is the specific cause, not a blanket disable. A security regression adopted
  pre-emptively for a feature nobody uses is not a trade, it is a giveaway.

### C74 — one owner for the NetworkManager unmanaged-devices key [DECIDED]

`my/system/core/default.nix:161` remains the single owner. It already carries the most complete list and, in
particular, the `podman*`/`docker*`/`br-*` entries that keep NetworkManager off the live Radicle forge.

- The cluster domain **contributes its CNI's interface names** to that one file rather than writing a second.
- nixpkgs' `rke2-canal.conf` is forced off:
  `environment.etc."NetworkManager/conf.d/rke2-canal.conf".enable = lib.mkForce false`.
- The duplicate writers at `my/infra/k3s/default.nix:33` and `my/infra/github-runner/default.nix:329` are
  removed as part of the same work.
- Rationale for not moving ownership into the cluster domain: core's list protects a workload that has
  nothing to do with Kubernetes, and a forge outage caused by a cluster module rewriting a shared key is
  exactly the coupling C64 exists to prevent.

### C75 — resolved: the Cilium chart pin, and the template nixpkgs already provides [VERIFIED]

Two sweep agents disagreed on RKE2's Cilium pin. Settled by reading the clone:

- `rke2/charts/chart_versions.yaml` pins **`rke2-cilium` 1.19.601** (Cilium v1.19.6) at master
  (`d6b3ae6b`, 2026-09-03), alongside `rke2-canal` v3.32.1-build2026082700 and `rke2-calico` v3.32.100.
  The claim that rke2-charts pins 1.20.1 is **wrong**. Upstream Cilium stable is ahead of this; the lag is
  real and cannot be bumped without bumping rke2, but it is a property of RKE2's packaged-CNI model and
  applies equally to canal and calico, so it is not a Cilium-vs-canal discriminator.

- C72 said choosing Cilium leaves the only CI-tested NixOS path. That stands — `nixos/tests/rancher/default.nix`
  loads only `images-canal-linux-{amd64,arm64}-tar-zst` (lines 60, 64). **But the same suite hands us the
  mechanism**: `nixos/tests/rancher/multi-node.nix` is a working two-node RKE2 cluster on NixOS that verifies
  cross-node pod networking with a DaemonSet and pins the CNI's interface through
  `rke2.manifests.canal-config.content` carrying a `HelmChartConfig` (lines 107-124), with a comment at :113
  recording that RKE2 *has* to be configured this way rather than by a flag.

  That is precisely the mechanism this fleet needs to pin the datapath to `tailscale0`, already exercised in
  CI. `tests/vm-rke2-cluster.nix` should be modelled on it as well as on `tests/vm-radicle.nix`, substituting
  the cilium airgap image set for the canal one. The departure from the tested path is therefore narrower
  than C72 implies: the *wiring* is tested, the *CNI* is not.

### C76 — RKE2 sets panic-on-oops machine-wide, ungated [VERIFIED — highest-hurt finding]

`services.rke2.enable = true` writes four sysctls **machine-wide, for every host that enables RKE2**, whether
or not CIS hardening was asked for:

```nix
config = lib.mkIf cfg.enable (          # rancher/rke2.nix:123
  ...
  boot.kernel.sysctl = {                # rancher/rke2.nix:144  <-- NOT under cisHardening
    "vm.panic_on_oom" = 0;
    "vm.overcommit_memory" = 1;
    "kernel.panic" = 10;
    "kernel.panic_on_oops" = 1;
  };
  users = lib.mkIf cfg.cisHardening {   # rancher/rke2.nix:151  <-- only THIS is gated
```

The comment above the block says "CIS hardening", but the guard covers only the `users` block beneath it.
yoga is currently `kernel.panic = 0`, `kernel.panic_on_oops = 0`; enabling RKE2 flips both.

**Why this is the highest-hurt item in the whole analysis, and why it has nothing to do with Kubernetes.**
yoga's root is a 16 GB tmpfs. `kernel.panic_on_oops = 1` turns any kernel oops into a panic, and
`kernel.panic = 10` reboots ten seconds later — and a reboot **discards the root filesystem**. yoga is a
daily-driver desktop running amdgpu, a driver this fleet already carries a custom kernel branch for; a GPU
oops that today degrades a session would instead wipe the root, on the one machine whose `my/forensics/`
exists to investigate exactly such events. The blast radius is the workstation, not the cluster.

- **C76.** The cluster domain must `lib.mkForce` each of these four keys back to the fleet's intended values.
  Per-key, not by overriding the attrset wholesale — a future nixpkgs bump that adds a fifth key must surface
  as a visible change, not be silently swallowed.
- **C77.** The resulting sysctl values must be **asserted in the VM test**. If a nixpkgs bump adds another
  kernel-level side effect, that must fail a test rather than reboot a workstation. This is the guardrail for
  a bug class — "an upstream module reaches outside its own domain" — not for one instance of it.
- Note these are plain values, not `mkDefault`, so any other module setting the same key is a definition
  conflict rather than a merge. `mkForce` is required, not merely preferred.

### C78 — `tls-san` has no nixpkgs option, and the SAN must exist before first start [VERIFIED]

The module's entire option surface is: `agentToken`, `agentTokenFile`, `autoDeployCharts`, `charts`,
`configPath`, `containerdConfigTemplate`, `disable`, `environmentFile`, `extraFlags`, `extraKubeletConfig`,
`extraKubeProxyConfig`, `images`, `manifests`, `nodeIP`, `nodeLabel`, `nodeName`, `nodeTaint`, `role`,
`selinux`, `serverAddr`, `token`, `tokenFile`, plus rke2's `cni` and `cisHardening`. **There is no `tlsSan`.**

C23 requires nodes to address each other by MagicDNS name. The server's serving certificate is generated
**once, at first start, and then persisted** — so if the MagicDNS name is not in its SAN list from the
beginning, every agent connecting to `https://<host>.<tailnet>.ts.net:9345` fails certificate validation, and
the fix is imperative surgery against persisted state (delete the CA and re-bootstrap, or rotate certificates
by hand) rather than a rebuild.

- **C78.** The MagicDNS SAN is passed through `extraFlags` (or `configPath`) and **must be decided before the
  cluster first starts.** It is on the critical path in a way nothing else in this document is: everything
  else can be fixed by changing the config and rebuilding.
- Include every name a peer might use — the MagicDNS name, the short hostname, and the tailnet IP — because
  adding one later costs the same surgery as forgetting all of them.

### C79 — correction: the quorum rationale for single-server was wrong [REFUTED]

This document (Topology) argued against HA by observing that a 2-member etcd has quorum 2. That is true and
**irrelevant**, because `skyspy-dev` was never going to be a server: **an agent is not an etcd member at
all.** The real argument for a single server is simply that this fleet has exactly one always-on machine, and
three always-on members do not exist to be had.

Relatedly, RKE2 **defaults to embedded etcd**, not sqlite (`rke2/pkg/cli/defaults/defaults.go:24`), and the
sqlite path is reachable only by overloading `--disable-etcd` — which RKE2's own source describes as
overloading (`rke2/pkg/rke2/rke2_linux.go:53-57`). Earlier text in this conversation that described the
single server as "sqlite, no etcd" was wrong. The single-server decision stands unchanged; only its stated
mechanism and rationale were incorrect. **Whether to run embedded etcd or force the sqlite path is an open
item**, and it changes which directories C33 must persist.

### C80 — CORRECTS C61: persist the state root SURGICALLY, not wholesale [VERIFIED]

C61 said the image store needs no separate declaration because "persisting the distribution's state root
covers it". That is **wrong**, and the reason matters.

`rancher/default.nix:834-873` renders `manifests`, `images` and `charts` as **systemd-tmpfiles `L+` symlinks
into `/nix/store`**, under paths that sit inside the state root:

```
manifestDir = /var/lib/rancher/<dist>/server/manifests   # default.nix:27
imageDir    = /var/lib/rancher/<dist>/agent/images       # default.nix:28
```

`L+` creates-or-replaces a symlink; it **never prunes** one whose declaration has gone away. Persist
`/var/lib/rancher` wholesale and every manifest ever declared leaves a symlink in `/persist` pointing at a
store path that will eventually be garbage-collected — and RKE2's deploy controller keeps trying to apply
them. A manifest you renamed six months ago is still being reconciled, from a dangling link, with nothing
naming the cause.

- **C80.** Persist the *stateful* subtrees, not the state root:
  - **persist** the containerd content store (`…/agent/containerd`) — this is the RAM fix C61 was after;
  - **persist** the server's datastore, CA and credentials — server role only, per C60;
  - **persist** `/etc/rancher` in full (see C81);
  - **never persist** `…/server/manifests`, `…/agent/images` or the charts directory. They are declarative
    outputs of the Nix build; persisting them makes a rebuild's deletions ineffective.
- The exact leaf paths come from the configuration reference, read out of the sources. Do not guess them here.

### C81 — node identity lives in TWO places, and half-persisting is worse than neither [VERIFIED mechanism]

The node-password file is created if absent and read thereafter (`k3s/pkg/agent/config/config.go:205-221`,
shared with RKE2); a mismatch against what the server holds is a hard failure —
`Node password rejected, duplicate hostname` (`:180`).

That produces three outcomes, and only two are stable:

| Persisted | Result |
|---|---|
| `/var/lib/rancher` **and** `/etc/rancher` | correct — the node rejoins as itself |
| **neither** | self-heals — the node re-registers cleanly as a new-but-identical node |
| **one of the two** | **broken every boot** — the server remembers a password the node no longer has |

- **C81.** Persist both or neither. The half-persisted state is the one a partial declaration produces by
  accident, and it fails at *re-registration*, not at boot, so it looks like a network problem.
- `my.system.persistence.features` has **no `systemFiles` option** — only `systemDirectories`,
  `userDirectories` and `userFiles` (`my/storage/impermanence/options.nix:53-63`). A single file therefore
  cannot be persisted at system level, so `/etc/rancher` must be declared as a whole directory. (Adding
  `systemFiles` to mynixos would be a reasonable follow-up; it is not required for this work.)
- **The VM test must reboot a node and assert it rejoins with the same identity.** This is the only assertion
  that distinguishes the three rows above, and none of the others in the suite would catch the broken one.

### C82 — bootstrap by tailnet IP, identify by MagicDNS name [VERIFIED tension, resolved]

C23 requires nodes to address each other by MagicDNS name. That cannot apply to `serverAddr`: `tailscaled`'s
resolver is not up when rke2 starts, so an agent bootstrapping against a MagicDNS name fails to resolve it.

- **C82.** Split the two concerns. **Node identity is a name** (C23 stands — `nodeName`, the tls-san list of
  C78, and anything a human or a peer reads). **The bootstrap address is a literal tailnet IP**
  (`serverAddr`, and `--node-ip` set explicitly rather than inferred).
- This is not a workaround for the ordering fix in C65; it is independent of it. Even with rke2 correctly
  ordered after `tailscaled`, name resolution and interface availability are different readiness conditions.

### C83 — RKE2's default ingress takes port 443 from the live forge [VERIFIED LIVE]

`tailscale serve` currently holds `100.97.96.49:443` (and the v6 equivalent) proxying to `127.0.0.1:8781` —
the Radicle explorer — plus `:1989` for the node. RKE2's default `rke2-ingress-nginx` is a **hostNetwork
DaemonSet claiming 80 and 443 on every node it lands on**. Whichever binds first wins, and if nginx wins the
explorer stops answering with nothing logging a conflict.

- **C83.** `disable = [ "rke2-ingress-nginx" ]`. Cluster services are fronted with `tailscale serve` against
  their ClusterIPs, which is the idiom this fleet already uses.
- RKE2's own ports do **not** collide: 6443 and 9345 are free. Ingress is the only conflict, and it is
  avoidable rather than negotiable.

### C84 — MagicDNS in `/etc/resolv.conf` makes tailscaled a single point of failure for cluster DNS [VERIFIED LIVE]

`/etc/resolv.conf` on yoga reads `nameserver 100.100.100.100` (MagicDNS) plus `fd7a:115c:a1e0::53`.
`100.100.100.100` is a valid global-unicast address, so **kubelet's loopback-resolver detection does not
fire** and every pod inherits it. CoreDNS' upstream forwarder then becomes the local `tailscaled`.

The consequence is specific and current: **a `tailscaled` restart takes down all in-cluster DNS.** This fleet
shipped a tailnet liveness probe (`f2f7ce7`, `my/network/tailscale/default.nix:191+`) whose entire purpose is
to take a node down when reachability fails — so the recovery mechanism for one subsystem is a total DNS
outage for another.

- **C84.** Point kubelet's `--resolv-conf` at a file carrying real upstream resolvers, not at the MagicDNS
  stub. Cluster DNS must not depend on the daemon whose failure mode is "restart it".

### C85 — systemd-oomd will kill pods, and a killed cilium-agent looks like a CNI bug [VERIFIED]

`my/system/core/default.nix:136` sets `enableRootSlice = true` unconditionally — not `mkDefault`.
`kubepods.slice` is a direct child of the cgroup root, so **every pod is an oomd kill candidate from day one**
on a machine whose root is a 16 GB tmpfs competing with 28 GB `/tmp`.

A SIGKILLed `cilium-agent` is a whole-node network outage. It will be read as a Cilium bug, and every hour
spent debugging Cilium will be wasted.

- **C85.** Decide this explicitly in the bring-up milestone: either `mkForce` the root slice off, or set
  `ManagedOOMPreference` on `kubepods.slice` so the cluster is not the first thing sacrificed. Not deciding
  is itself a decision, and it is the wrong one.

### C86 — `pkgs.rke2` is a moving alias; skew is guaranteed by skyspy-dev's absence [VERIFIED]

`rke2 = rke2_stable` (`pkgs/top-level/all-packages.nix:12045`) and `rke2_stable = rke2_1_33`
(`pkgs/applications/networking/cluster/rke2/default.nix:49`) in the pinned nixpkgs — a **moving alias**.

skyspy-dev is away for months at a time. It rebuilds against whatever `rke2_stable` has become, returns
one or two minors ahead of yoga, and **an agent newer than its server does not join**. This is not a
hypothetical skew; the fleet's own usage pattern produces it.

- **C86.** Pin `services.rke2.package` to an explicit versioned attribute from **one shared place both hosts
  read**, the way this repo already pins vogix to a tag. A version pinned independently per host is the same
  bug with extra steps.

### C87 — `KillMode = process` leaves mounts that block unmounting `/persist` [VERIFIED mechanism]

The rke2 unit sets `KillMode = process`, deliberately leaving containerd and every pod running when the unit
stops. Nested pod mounts beneath a persisted kubelet directory then block unmounting `/persist` at shutdown.

- **C87.** Ship a shutdown-ordered `rke2-killall.sh` unit `Before = umount.target`, and enable
  `gracefulNodeShutdown`. **The VM test must assert a clean reboot** — this failure appears only at shutdown,
  which no other assertion in the suite reaches.

## Amendment: corrections from adversarial review of the decision record (2026-09-05)

Four citations in `docs/k8s-fleet-decision.md` did not survive checking. Three change a constraint here.

### C88 — `services.rke2` has NO assertions, only warnings [VERIFIED — corrects the decision record]

The decision record credited the shared rancher module with *asserting* that an agent has both
`serverAddr` and a token. It does not. `grep -n assertions` across
`rancher/{default,k3s,rke2}.nix` returns exactly **one** hit — `k3s.nix:125`. The rke2 path has none.

The serverAddr and token checks are `lib.optional` entries in a `warnings` list
(`rancher/default.nix:806`, checks at `:822-826`), and they are phrased "**should** be set if role is
'agent'". So a misconfigured agent **builds, switches, and fails at runtime**, having emitted one warning
line that `nixos-rebuild` scrolls past.

- **C88.** The cluster domain must carry its **own `assertions`** for the join contract: an agent has a
  `serverAddr`, an agent has a token from a sops-nix runtime path, a server has a tls-san list (C78), and the
  role/CNI combination is coherent. C11 requires joining to be declarative and idempotent, and until this
  module supplies them there is **no eval-time enforcement of that anywhere**.
- This is the difference between a typo caught by `nix flake check` and a node that silently never joins.

### C84 — CORRECTED: the liveness probe does NOT take a host down [REFUTED]

C84 claimed that the tailnet liveness probe (`f2f7ce7`) firing would take yoga down and therefore kill all
in-cluster DNS. **That is wrong**, and the module says so in its own comments:

- `my/network/tailscale/default.nix:189-190` — "Deliberately container-agnostic: on a host a failing probe is
  a failed unit and nothing more."
- `my/network/tailscale/default.nix:415` — "No FailureAction here: this module runs on hosts too, where the
  pair is simply two entries in `systemctl --failed`."
- The escalation comes from a `FailureAction` that a **container role** attaches
  (`my/virtualisation/containers/default.nix:329`), not from the host path.
- `my.network.tailscale.liveness` is **not enabled on yoga** at all.

**What survives, and is still worth fixing:** `/etc/resolv.conf` is MagicDNS `100.100.100.100`, a valid
global-unicast address, so kubelet's loopback detection does not fire, every pod inherits it, and CoreDNS'
upstream forwarder becomes the local `tailscaled`. **A `tailscaled` restart still kills in-cluster DNS.** The
mitigation is unchanged — point `--resolv-conf` at real upstreams. Only the escalation clause was invented,
and it inflated the risk.

### C67 — DOWNGRADED: the PLPMTUD rescue is unverifiable at the shipped version

C67 refuted C20's "silent black hole" on two legs: that the kernel fragments rather than dropping, and that
RFC 4821 PLPMTUD rescues TCP because "RKE2's chart ships `pmtuDiscovery.packetizationLayerPMTUDMode:
blackhole`". The second leg is **mis-attributed and unverifiable**:

- `pmtuDiscovery` appears nowhere in RKE2's cilium chart patch — it is **upstream Cilium's** default
  (`cilium/install/kubernetes/cilium/values.yaml`), read at `main`.
- The cilium clone is `--depth 1` (`git rev-list --count HEAD` = 1), so **when that default landed cannot be
  checked from the evidence on disk**, and the fleet runs 1.19.6, not `main`.

- **C67 (revised).** The fragmentation leg stands. The PLPMTUD-rescue leg is **unconfirmed at 1.19.6** and
  must not be relied on. Treat the consequence of a wrong MTU as *at least* throughput collapse and possibly
  worse. This strengthens rather than weakens the case for asserting the pod route MTU **directly** as a
  number (C66/C18) instead of inferring health from a payload arriving.

### C89 — device selection was overturned on the wrong citation

C65 superseded C16 (pod MTU must never be auto-detected) by citing `RT_TABLE_UNSPEC` in Cilium's device
controller. That line is the **route filter**, not the device-selection gate. Selection is `isSelectedDevice`,
whose final test is `hasGlobalRoute`, plus `defaults.ExcludedDevicePrefixes` and a type switch.

`tailscale0` does pass — verified live on yoga: type `tun`, `IFF_UP`, `MasterIndex 0`, per-peer /32s in table
52 and `local 100.97.96.49` in the local table. So the **conclusion holds**. But it was reached on an
uncited mechanism at a version that could not be checked, which is exactly the reasoning C67 was corrected
for. Pinning the MTU (C66) is what makes this moot, and is now the primary reason to pin rather than a
secondary one.

## Amendment: the implementation brief's corrections (2026-09-05)

### C90 — METHODOLOGY: verify against the PINNED nixpkgs, not an arbitrary store tree

Several verifications in this session were performed with
`find /nix/store -path '*...*' -print -quit`, which returns an **arbitrary** nixpkgs source tree — the store
holds many. The tree this flake actually pins is resolved with:

```
nix eval --raw --impure --expr 'let f = builtins.getFlake (toString ./.); in f.inputs.nixpkgs.outPath'
```

- **C90.** Any claim about nixpkgs is cited against the pinned tree or it is not cited. This is not
  pedantry: the arbitrary tree gave `rke2_stable = rke2_1_33` where the pinned tree gives `rke2_1_35` — a
  two-minor error in a constraint whose entire subject is version skew.
- **Re-verified against the pinned tree, all holding at identical line numbers:** C76's ungated panic sysctls
  (`rke2.nix:123` `mkIf cfg.enable`, `:144` sysctls, `:148` `panic_on_oops = 1`, `:151` the only
  `cisHardening` guard); C88's absent assertions (`k3s.nix:125` is the sole `assertions` in the directory);
  C80's `L+` symlinks (`:849` manifests, `:856` images, `:871` charts, `:879` containerd template); and the
  `cni` enum (`rke2.nix:84-92`).

### C86 — CORRECTED: the alias is `rke2_1_35`, and it has already moved

`rke2_stable = rke2_1_35` / `rke2_latest = rke2_1_36` in the pinned tree (`pkgs/applications/networking/cluster/rke2/default.nix:17-18`, aliased at `pkgs/top-level/all-packages.nix:9111`), pinning `rke2-cilium` 1.19.601
(Cilium v1.19.6). The earlier figure of `rke2_1_33` came from the wrong tree. The constraint is unchanged and
its point is sharpened: the alias **demonstrably moves**, so a fleet whose second node rebuilds after months
away will land on a different minor unless `services.rke2.package` is pinned from one shared place.

### C81 — REFUTED: persist `/etc/rancher/node`, NOT all of `/etc/rancher`

C81 reasoned that because no `systemFiles` option exists, the whole of `/etc/rancher` must be persisted to
keep the node password. That was wrong on the facts:

- **Only `/etc/rancher/node` is state**, and it **is a directory** — so the missing `systemFiles` option never
  applied. It holds `password` (0600) and, only under `--with-node-id`, `id`.
  (`k3s/pkg/agent/config/config.go:482-492`, `:205-222`, `:180`.)
- `rke2.yaml`, `rke2-pss.yaml` and `audit-policy.yaml` are **rewritten every start**, and the nixpkgs module
  never writes into `/etc/rancher` at all. Persisting the parent buys nothing and drags the **admin
  kubeconfig into `/persist`**, which C43 exists to prevent.
- yoga is server+agent, so its own server validates that file locally
  (`k3s/pkg/nodepassword/validate.go:134-141`) — a **single-node** cluster breaks on this too, not just a
  joining agent.

### C91 — the agent's certs and kubeconfigs are NOT node identity [corrects the Persistence table]

The Persistence table lists `…/agent/*.crt`, `*.key` and `*.kubeconfig` as node identity. They are not: they
are re-requested from the server and **overwritten unconditionally on every start**
(`k3s/pkg/agent/config/config.go:247-300`, `:735-745`). Persisting them is unnecessary, and it is what keeps
the final list short.

### C92 — additions to PERSIST and NEVER-PERSIST that C80 missed

**Add to PERSIST (both roles):** `/var/lib/rancher/rke2/data` — the rke2-runtime image is re-extracted here
at every start of both roles and `…/rke2/bin` is symlinked at it
(`rke2/pkg/bootstrap/bootstrap.go:51-64`, `:178-263`). nixpkgs' `no_stage` build tag does **not** disable
this. It self-prunes only while the runtime image is tag-pinned, which `builder.nix:104` is.

**Add to NEVER-PERSIST:**
- `…/agent/etc` — holds `containerd/config.toml.tmpl`, itself an `L+` symlink
  (`rancher/default.nix:29`, `:877-880`). C80's list missed this one.
- `…/agent/pod-manifests` — control-plane static pods, rewritten from config every server start
  (`rke2/pkg/executor/staticpod/staticpod.go:625-687`). A persisted stale one is a control-plane pod the
  kubelet keeps running that the current config no longer describes — **it survives the rebuild meant to
  remove it.**
- `…/server` (the parent) — accumulates `tls-<unixtime>` cluster-reset backups that are never pruned
  (`k3s/pkg/cluster/bootstrap.go:380-390`).

**Sharper than recorded:** persist `…/server/db` **whole**, never `db/etcd` alone. A missing `db/etcd/name`
on a server sets `clusterReset = true` on **every boot** (`rke2/pkg/rke2/rke2_linux.go:89-91`) — an
RKE2-specific failure worse than the generic "node identity destroyed" the table describes.

### C93 — the server runs ON yoga, not in a guest [DECIDED after adversarial review]

The decision record's open item #4 claimed a guest "removes six of fourteen risks rather than mitigating
them". It was evaluated and then attacked. **The conclusion survives; the ledger did not.**

**The structural kill, which needs no measurement.** C13 already records that **no mynixos module provisions a
VM**, and this same decision *deferred* aether5d-dev's VM node on exactly that gap. Nominating the **single
control-plane member** — C7's "only machine whose absence is not routine" — as the debut customer of a
mechanism the same milestone declined to build for a peripheral client **inverts the risk ordering**. No
reachability test can fix that.

**The corrected ledger.** Of the six risks claimed removed, at most one is:

| Risk | Claimed | Actual |
|---|---|---|
| R1 panic sysctls | removed | **MOVED** — the block is inside `mkIf cfg.enable`, so the guest gets `panic_on_oops=1` too, and nobody will `mkForce` it there because not having to was the point |
| R2 NM clobber | removed | **RELOCATED**, zero lines saved — mynixos sets NM `mkDefault true` on every Linux system, so the guest gets `rke2-canal.conf` too |
| R5 image store on tmpfs | removed | **NOT REMOVED** — `virtualisation.diskImage` defaults to a path resolved into the unit's WorkingDirectory (`/`, the tmpfs) before the script `cd`s to `$TMPDIR`; the naive configuration is the default |
| R6 identity, two paths | removed | **NOT REMOVED** — a persistent qcow2 persists *everything*, including the `L+` symlink dirs C80 forbids: the C80 anti-pattern with a hypervisor around it, opaque to every persistence diff |
| R9 oomd | reduced | **REVERSED** — no virtio-balloon, so guest memory is a one-way ratchet on a box whose only swap is zram at 100%; oomd's kill granularity becomes the whole cluster instead of one pod |
| R13 shutdown | removed | **REVERSED** — `KillMode=process` is what makes a *host* restart cost seconds; in a guest a restart is a power-cycle, and yoga took 8–34 generations per day last week |
| R14 MagicDNS | removed | **NOT REMOVED** — the guest runs its own tailscaled and nothing passes `--accept-dns=false`. The only topology that would remove it violates C21/C23/C24/C82, so the fix and the credit can never be claimed together |

Removed: **arguably one** — the desktop kernel's sysctls — against ~15 lines of `mkForce`/`disable`/logging
that are already specified and **verifiable at eval time**, which a hypervisor is not.

**Not priced by anyone, and decisive for future workloads:** yoga has **no dGPU**
(`/etc/nixos/systems/yoga/default.nix:232`), so a VM node could never be given GPU access — passthrough would
take the Hyprland display with it. Host-run RKE2 hands `/dev/dri` to a pod trivially. A guest permanently
forecloses the one workload class this host's hardware, its 16 GB `/tmp/gpu-workdir` and its live amdgpu work
make plausible.

- **C93.** The server runs on yoga's host OS. **The trigger to revisit** is narrow and specific: yoga's
  amdgpu patched-kernel specialisation (`/etc/nixos/systems/yoga/default.nix:457-489`, currently commented
  out as "TEMPORARILY DISABLED") being re-enabled while RKE2 runs on the host. That series exists to study
  GPU fault storms; deliberately provoking oopses on a machine carrying `kernel.panic_on_oops = 1` with a
  tmpfs root is the one configuration where a four-line `mkForce` stops being an adequate answer to R1.
  Two qualifications: it covers only the *oops* class — the CPU livelock the specialisation actually chases
  halts the host and takes any guest with it — and the C13 mechanism gap must be closed **before** the
  control plane moves, not during.
- **Do not** record a reachability test as the trigger. A direct tailnet pong would refute the DERP objection
  and change nothing about C13, C80, restart granularity or unreclaimable RAM.
- **Standing fact worth keeping:** yoga reaches its own rootless-podman guests at **DERP(den), 21–28 ms** —
  host to guest, via Denver. That is a real cost of the existing forge topology today, and the
  `tailscale.com/cap/relay` grant naming yoga (`relayServerPort` is configured and inert without it) is worth
  pursuing on its own merits.

### C94 — the datastore is embedded etcd, and the reason is recoverability not defaults [DECIDED]

Not "don't fight the default". **On the sqlite/kine path RKE2 has no snapshot mechanism, no restore, no
cluster-reset and no S3 target — not disabled, absent.** All four are gated on a `managedDB`, and
`k3s/pkg/cluster/managed.go:3-4` states that kine is not one; `managed.go:29-31` returns nil before any of it
runs.

So the choice is not "etcd's write amplification vs sqlite's simplicity". It is **the datastore that ships a
periodic snapshot, a supported restore and an off-box destination, against the one that ships none of the
three** — on a machine whose root is a 16 GB tmpfs, whose sysctls RKE2 itself flips to `panic_on_oops = 1`
and `panic = 10` (C76), and whose pods are all systemd-oomd kill candidates (C85). Those three risks *raise*
the probability of precisely the event only etcd can recover from.

Supporting, all verified: RKE2 never CI-tests sqlite (its `kine` e2e job runs MySQL); the sqlite branch emits
a config key the parser turns into the four-dash argument `----disable-etcd=true`, so it has almost certainly
never executed as written; and RKE2's sqlite path is not plain sqlite — it turns on `KineTLS` and the
external-database path (`rke2_linux.go:56-68`), so the simplicity argument does not survive either.

- **C94.** Embedded etcd. **It adds nothing to the persistence list** — both datastores live inside
  `/var/lib/rancher/rke2/server/db` (etcd as `db/etcd/` + `db/snapshots/`, kine as `db/state.db`). Do **not**
  write a datastore conditional into the expression.
- Sharpens C80: `server/db` is not merely the datastore, it is the **authoritative copy of the CA** —
  `server/tls` and `server/cred` are reconciled *from* it on every start
  (`k3s/pkg/cluster/bootstrap.go:34-84`, `:248-330`). That is the code that makes "a regenerated CA is a
  different cluster wearing the old hostname" true.
- Reversibility: sqlite → etcd is an automatic in-place migration; **etcd → sqlite has none**. Starting on
  etcd forecloses nothing.
- Do **not** justify etcd by "we can add a second server later". C79 is unchanged: the useful step is one to
  three, never one to two.

### C95 — snapshots are on by default and go nowhere useful [DECISION REQUIRED BEFORE FIRST START]

RKE2 takes etcd snapshots on `0 */12 * * *` with retention 5, uncompressed, into `server/db/snapshots`
(`k3s/pkg/cli/cmds/server.go:400-438`; `defaultSnapshotRetention = 5` at `:13`). That is **~2.5 days of
history, inside the directory being persisted, on the same partition, on the same machine.**

- **C95.** **The snapshot destination is the real decision, not the datastore.** Settle it before first
  start, in the same breath as C78's tls-san — both are cheap now and surgery later.
- Three shapes: `etcd-s3` to a bucket (needs an endpoint this fleet does not obviously have, and a credential
  that must not reach `/nix/store` — C-secrets applies); `--etcd-snapshot-dir` pointed somewhere replicated
  off-box; or a systemd timer copying snapshots to another tailnet node. Note the third may have no
  destination: skyspy-dev is gone for months and aether5d-dev is a client.
- If a custom directory is used, **mynixos must pre-create it with a tmpfiles rule** — rke2 deliberately
  refuses to `mkdir` a non-default snapshot dir (`k3s/pkg/etcd/snapshot.go:82-84`).

### C96 — `/persist` is btrfs CoW with autodefrag, and etcd is about to live on it [VERIFIED LIVE]

Verified on yoga: `/dev/nvme0n1p4[/persist] btrfs rw,noatime,ssd,discard=async,space_cache=v2,**autodefrag**`,
declared at `/etc/nixos/systems/yoga/disko.nix:68-80`. A repo-wide grep for `nodatacow|chattr` returns
**nothing** — copy-on-write has never been disabled anywhere on this fleet.

An fsync-per-transaction database on CoW **plus autodefrag** is the classic bad combination. Every other
constraint in this document argues about *which directories* to persist; **none of them looks at the
filesystem underneath**, and on this machine that is the larger lever.

- **C96.** Fix it directly, not by retreating to sqlite: either a dedicated `nodatacow` subvolume in
  `yoga/disko.nix`, or `chattr +C` applied at provisioning time. `+C` only takes effect on a directory
  **before any file exists in it**, so it must be a tmpfiles rule or an `ExecStartPre`, never a post-hoc fix.
- **Measure before choosing the shape**: etcd's own slow-fsync warnings and
  `etcd_disk_wal_fsync_duration_seconds` p99 on the running cluster. This is a real question with a cheap
  measurement, not a foregone conclusion.
- Related: persisting `agent/containerd` moves the overlayfs snapshotter root onto btrfs, and containerd
  validates snapshotter support at every start (`config_linux.go:23-28`). Worth one explicit check at
  bring-up.

## Amendment: decisions at the architecture gate (2026-09-05)

- **Architecture approved** as recorded in C93 (host, not guest) and C94 (embedded etcd).
- **C95 deferred, deliberately.** etcd snapshots keep RKE2's default — `0 */12 * * *`, retention 5, into
  `server/db/snapshots`. The owner accepts that this leaves **no recovery from the loss of yoga's disk**,
  and chose to revisit rather than block first bring-up on picking an off-box destination. Recorded so the
  gap is a decision with a name on it rather than an oversight. It remains cheapest to fix before first
  start, alongside C78's tls-san.
- **C96 REOPENED — do not act on it as written.** C96 proposed a `nodatacow` subvolume in `yoga/disko.nix`.
  The owner objected that changing disko implies reformatting a disk that carries the live Radicle forge, and
  asked whether anything is better than etcd's WAL. **That objection is correct to raise and the constraint
  as written was unsafe**: it named a fix without establishing whether it can be applied to a live system.
  Under research with **"the disk cannot be reformatted" as a hard constraint**. Until it resolves, **m1 must
  not assume any disko change**, and the `chattr +C` route must not be adopted casually either — it silently
  no-ops on a non-empty directory, which is the worst shape a mitigation can take.
- **CLAUDE.md corrected** as part of this work: `platforms/oci.nix` → `oci-variant.nix` described as a
  *variant* rather than a platform; `platform = "oci"` and the "`vm` will be another" line removed, with the
  `a453a96` doctrine ("adding a format is adding an output, never a platform") stated positively; the
  `roles/` reference removed and replaced with where that configuration actually lives; the
  `docs/radicle-containers.md` pointer corrected. Every claim checked against `lib/mkSystem.nix:212-214`,
  `platforms/`, and the `a453a96` commit message.

## Amendment: C96 resolved — etcd on btrfs CoW (2026-09-05)

Researched with **"the disk cannot be reformatted"** as a hard constraint, then adversarially reviewed. The
answer overturns C96 as written and, more usefully, overturns the premise underneath it.

### C97 — THREE WAYS TO LOSE DATA, recorded first because they are actionable today

1. **The obvious migration procedure destroys the live datastore and reports success.** Under impermanence,
   `/persist/<path>` is the **source** of a bind mount (`impermanence/nixos.nix:292-308`). Renaming the mount
   source does **not** move the mount — the runtime path keeps resolving to the original inode. So a
   `mv /persist/…/db …/db.cow` + recreate + `rm -rf …/db.cow` sequence leaves rke2 running on the **old**
   data (the mitigation silently no-ops), `lsattr -R` inspects the new decoy directory and reports all-NOCOW
   (it looks like it worked), and the final `rm -rf` **deletes the files etcd is running on**. Reproduced in
   a user namespace. **Rule: operate strictly inside the bind-mounted subtree, never on the mount source.**
   Verified live: **85** `nvme0n1p4` bind mounts, including `/var/lib/radicle-forge`,
   `/var/lib/radicle-seed-forge`, `/var/lib/radicle-identity`.
2. **`nix run '.#nixosConfigurations.yoga.config.system.build.diskoScript'` wipes `/dev/nvme0n1` with no
   prompt.** It is `_legacyDestroy` + `_create` + `_mount`, and `_legacyDestroy`'s own description is
   *"Does not ask for confirmation!"*. The modern `disko` CLI is safe by comparison — its default mode is
   `mount`, and `_destroy` demands a typed `yes`.
3. **`/var/lib/rancher` is not persisted today and nothing in the plan had noticed.** Verified: `stat` returns
   *No such file or directory*, `findmnt` shows no bind mount for it, `/var/lib/kubelet` or `/var/lib/cni`.
   The only declaration in the repo is `my/infra/github-runner/default.nix:496`, in a module that is **off**.
   Without C80's declaration the datastore *and the cluster CA* land on the tmpfs root, and
   `rke2/pkg/rke2/rke2_linux.go:89-91` then sets `clusterReset = true` **on every boot** — a new cluster
   wearing the old hostname, every reboot. **This gates everything else.**

### C98 — editing `disko.nix` does NOT reformat on rebuild [VERIFIED]

The premise behind C96's rejection was false, though the caution was right.

`nixos-rebuild switch` builds only `config.system.build.toplevel`. disko's format and destroy scripts are
**lazy siblings** of toplevel under `system.build` and are never referenced. disko's entire NixOS `config`
block is assertions, `_module.args`, `system.build.*` and `fileSystems`/`boot`/`swapDevices` — **no
activation script, no systemd unit, no initrd hook.** Proof on this machine:

```
nix-store -qR $(nix-store -q --deriver /run/current-system) | grep -ci disko   →  0
```

on a host that demonstrably uses disko.

- **C98.** The rule is not "never edit disko.nix". It is **"never run `disko --mode destroy` or
  `system.build.diskoScript` on an installed host"**.
- **But there is a real live cost, and it is not data loss.** A disko edit rewrites `/etc/fstab`, and
  switch-to-configuration acts on the diff: an options-only change **remounts**, a device/fsType change
  unmounts and remounts, a removed entry **unmounts**. Only `/` and `/nix` are exempt — **`/persist` is
  not**, and it carries 85 bind mounts and the live forge. Changing `/persist`'s `mountOptions` in disko
  would remount it underneath all of them. That is a forge and desktop outage, not a wipe.
- `/persist` is `neededForBoot`, so a *wrong* `/persist` entry is a boot failure rather than a failed switch.
- disko never inspects the live disk. Drift is inert documentation that produces no error **ever**, until a
  reinstall silently fails to recreate whatever is missing.

### C99 — etcd on CoW is a non-issue at this scale [MEASURED on this hardware]

Measured on `/persist` itself, under the exact mount options etcd will run with:

- WAL-shaped `fdatasync` **p99 3.3–5.8 ms** against etcd's published 10 ms target, and **zero of 24,000
  samples** exceeded the 1000 ms `slow fdatasync` threshold (`etcd server/storage/wal/wal.go:45-47`).
- Backend commit **p99 4.1–5.0 ms** against a 25 ms target.
- RKE2 has already widened the ladder ~5× — heartbeat 500 ms, election 5000 ms, `ReqTimeout` 15 s
  (`k3s/pkg/etcd/etcd.go:1047-1050`). Roughly three orders of magnitude of headroom.
- **The leader-election half of the folklore is structurally unreachable with one member.** `QuorumActive()`
  visits only self, whose `RecentActive` is permanently true. A lone member cannot step down however slow the
  disk gets.
- The folklore comes from spinning rust. On this NVMe, **26,134 extents read 5% slower than 1 extent**.
- Endurance is a non-argument: yoga already writes **415.6 GB/day** to this SSD; the whole CoW-vs-NOCOW delta
  for etcd is 13–42 GB/day.
- The penalty does **not** compound — over 20,000 commits p50 improved and autodefrag bounded extent count,
  then collapsed it.

**No measured etcd-on-btrfs benchmark exists in public.** The transferable published evidence is a null set;
the figures above are more specific to this hardware than anything in print.

- **C99.** Do **not** change the filesystem layout for this. C96 is withdrawn as written.
- **What is genuinely real, and was being crowded out by the CoW argument:** *etcd-internal bbolt
  fragmentation* — the only measured k3s failure of this class in the wild (k3s#13911: 69% fragmentation,
  load 76, 80+ minutes degraded). It is **filesystem-independent** and happens on ext4 too. RKE2 defrags only
  at startup and above 100 MB, and the pinned etcd has no `--auto-defrag-mode`. **This deserves the attention
  CoW was getting.**
- Optional, cheap, and justified as *fragmentation control* rather than latency: `chattr +C` on
  `…/server/db/etcd` via a prepare oneshot **on the runtime path, before first start**. It must never be
  applied to the `/persist` mount source, and it silently no-ops on a non-empty directory — so it is worth
  doing only if `lsattr` verifies it afterwards.

### C100 — the answer to "is there something better than etcd's WAL?"

**The WAL is not the problem**, so nothing needs to be better than it. The measured fsync path has three
orders of magnitude of headroom on this hardware, and the failure mode the folklore warns about cannot occur
on a single-member cluster. The datastore decision (C94, embedded etcd) stands unchanged, and it stands for
recoverability — kine has no snapshot, restore, cluster-reset or S3 target at all.

## Amendment: replication — the answer, and it is not about etcd (2026-09-05)

### C101 — the irreducible state is 2.3 KB of sops ciphertext, and it exists on one disk [VERIFIED]

The question "how do we replicate the cluster" has a smaller answer than it looks, and answering it surfaced
a **pre-existing single point of failure that has nothing to do with Kubernetes**.

With workloads carried by `services.rke2.manifests` / `autoDeployCharts` (already required by C80) and the
join token carried by `tokenFile`, a rebuild from the flake on new hardware produces a working cluster with a
freshly generated CA and **no restore at all**. An etcd snapshot preserves in-cluster *mutable* state, of
which there is currently none — the cluster does not exist yet.

What is genuinely irreplaceable:

| Artefact | Size | Where it lives | Status |
|---|---|---|---|
| sops `secrets.yaml` ciphertext | **2,316 bytes** | two copies, **both on `/dev/nvme0n1p4`** | **irreducible, unreplicated** |
| RKE2 cluster token | 32 hex chars | does not exist yet | make it a sops key → folds into the row above |
| etcd snapshot | ~9 MB modelled | does not exist yet | **convenience, not a dependency** |
| everything else | — | — | reconstructible from Nix or sops |

Verified live: `~/.secrets` is `/dev/nvme0n1p4[/persist/home/logger/.secrets]`, is **not a git repository**,
and `/persist/etc/sops/secrets.yaml` is the second copy **on the same partition**. `secrets.yaml` is
confirmed sops ciphertext.

**The decryption keys are already safe.** `.sops.yaml` encrypts to three recipients — two YubiKeys plus
yoga's age key — and either token alone decrypts. Losing yoga's disk does **not** cost the ability to decrypt.
It costs **the ciphertext itself**, which is the only copy of the thing the keys open.

- **C101.** `allowSecretsInStore` made *off-store* a discipline, and it has been read as *off-box*. **It is
  not.** An age+PGP-encrypted sops file is safe to publish **by construction** — that is the entire point of
  encrypting it — and this fleet already pushes to GitHub successfully. Getting `secrets.yaml`, `.sops.yaml`
  and `hosts/` into a repository is a five-minute change that protects against the only failure that matters,
  and it is worth more than every snapshot mechanism considered.
- **C102.** The RKE2 cluster token goes in sops from the start (C-secrets), never chosen by hand. It is the
  whole restore story: every snapshot's `/bootstrap/<hash>` blob holds every CA private key plus
  `EncryptionConfig`, AES-GCM under PBKDF2 over the token. **Snapshot without token = an unopenable file.**
  Token without snapshot = a fresh cluster, which is fine. Let RKE2 generate it once, then store it.

### C103 — DANGER: `/home/logger/.secrets` holds an unencrypted private key [VERIFIED]

Any instinct to `git init && git add -A` in that directory **must not be acted on**. Verified by listing
(contents never read):

```
-rw-------  399  radicle-node-key.UNENCRYPTED   <- PLAINTEXT ed25519 private key
-rw-------    0  radicle-node-key.enc           <- ZERO BYTES; the .enc is a lie
-rw-------  2452 radicle.json                   <- mode 600, treat as secret
-rw-r--r--  2316 secrets.yaml                   <- SAFE: sops ciphertext
-rw-------  595  .sops.yaml                     <- SAFE: public recipients only
lrwxrwxrwx       result -> /nix/store/...       <- root-owned symlink, unrelated
```

This is the **same class of mistake** as the flake-input interpolation that previously copied this key into
`/nix/store` — and that key has not been rotated.

- **C103.** If the directory is versioned, commit an **explicit allowlist** (`secrets.yaml`, `.sops.yaml`,
  `hosts/`) behind a `.gitignore` of `*` with `!` exceptions, and inspect `git status` before the first push.
  Never `add -A`. Better: keep the ciphertext in a repository that has never contained the plaintext at all.

### C104 — rejected: pre-seeding CA files into the server TLS directory [REJECTED, data-destroying]

A proposal to pre-seed CA material into `…/server/tls` was found to **kill the cluster on ordinary reboots**:
`ReconcileBootstrapData` calls `logrus.Fatal` when an on-disk bootstrap file differs and is ≥3 s newer than
the datastore (`k3s/pkg/cluster/bootstrap.go:389`, `systemTimeSkew = 3` at `:223`). The `ClusterReset` branch
skips that check, so it bites on **restarts** and not on restores — the worst possible timing. Compounded by
sops activation running in `initrd-nixos-activation.service` while impermanence bind mounts are stage-2, so
the write lands on tmpfs and is shadowed. **Rejected outright**; C101 shows it is not needed.

Also rejected: `rsync --delete` from yoga to any destination — it propagates RKE2's retention pruning, and any
corruption or compromise, to the copy.

### C105 — when snapshot shipping IS built, the shape is decided

Deferred deliberately (C95), but the design is recorded so it is not re-derived:

- Keep RKE2's **default** snapshot directory and **copy out**. Never repoint `--etcd-snapshot-dir`: rke2
  refuses to `mkdir` a non-default one, and a tmpfiles-created directory loses the race to the bind mount
  **silently, with rke2 exiting 0**.
- `age -R` the snapshot **before it leaves yoga**, to a recipient neither machine holds.
- **Push into an append-only forced-command receiver** (`restrict,command="…"`, the idiom already at
  `my/dev/remote-builders/darwin.nix:61`) so a **compromised yoga cannot delete its own history**. Direction
  matters more than destination here.
- A backup nobody restores is not a backup: the acceptance test restores a snapshot into a fresh VM and
  asserts the cluster comes up — which fits the `tests/vm-*.nix` idiom this repo already has.

### C106 — secrets work is OUT OF SCOPE for this run [DECIDED]

C101–C103 surfaced a real, pre-existing single point of failure and an unrotated plaintext key. **None of it
is actioned here.** The owner's direction: secrets get their own session, when key material is recycled and
rotated wholesale — first make the cluster work.

That is the right sequencing and it is recorded rather than merely obeyed, because the findings are easy to
lose:

- **Do not** create a git repository in `/home/logger/.secrets` as part of this work.
- **Do not** rotate, move or re-encrypt anything.
- The cluster's own token still goes into sops from the start (C102) — that is cluster work, not secrets
  work, and it costs nothing now while being surgery later.
- C101 and C103 stay open, owned by that future session. They are not blockers for bring-up: the cluster can
  be built, tested and deployed without touching any of it.

### C107 — removing a DSL option breaks any consumer that MENTIONS it, not just one that enables it [VERIFIED]

m1 removed `my/infra/k3s` on the decision record's justification that it was *"dead code (never enabled on any
host)"*. That was true about **enabled** and wrong about **referenced**:

```
/etc/nixos/systems/skyspy-dev/default.nix:75:  k3s.enable = false;   # Disable k3s on laptop
```

Setting an option to `false` still requires it to exist. Verified:

| host | result |
|---|---|
| yoga | evaluates — mentions k3s only in a comment |
| **skyspy-dev** | **`error: The option 'my.infra.k3s' does not exist`** |

`nix flake check` did **not** catch this: it checks mynixos, and the break is in the consumer flake. **Only the
both-hosts closure gate sees it**, which is precisely why that gate builds yoga *and* skyspy-dev rather than
whichever host is convenient.

- **C107.** A DSL option removal and its consumer-side cleanup are **one change across two repositories**.
  They must land together, and the closure gate over both hosts is what proves it. Until the consumer drops
  the line, the working tree is in a state where one of two hosts does not build.
- The nixpkgs-idiomatic softener, if a removal ever needs a transition window, is
  `mkRemovedOptionModule` — it keeps the option declared and fails with a message naming the replacement,
  instead of the module system's generic "does not exist". Not needed for a two-host fleet where both sides
  land together, but it is the tool for the case where they cannot.

### C108 — BLOCKER: Cilium v1.19.6 does not start on this fleet's kernel [VERIFIED by running it]

The VM test booted a real two-node cluster and the CNI **crash-looped on both nodes**:

```
level=fatal msg="failed to probe helper"
  error="detect support for FnSetRetval for program type CGroupSock: load program:
         invalid argument: 0: (85) call bpf_set_retval#187: R1 is not a scalar"
  progType=CGroupSock helper=FnSetRetval
```

**This is not a VM artifact.** The guest ran Linux **7.2.2**; yoga runs **7.2.0**. Both take
`linuxPackages_latest`, which is the fleet default (`my/system/kernel/default.nix:56`). The eBPF verifier in
7.2 rejects the probe program Cilium 1.19.6 loads.

**There is no bypass.** `pkg/datapath/linux/probes/probes.go:81-93` returns cleanly only for
`ebpf.ErrNotSupported`; **any other error is `logging.Fatal`**. A verifier rejection is not
`ErrNotSupported`, so Cilium cannot tell "this kernel lacks the helper" from "my probe is malformed for this
kernel" and terminates. No flag, no config key, no chart value disables it.

**And the version cannot be bumped independently.** RKE2 pins `rke2-cilium` **1.19.601** in
`charts/chart_versions.yaml`, still at master (`d6b3ae6b`, 2026-09-03), so this is not fixed by moving to a
newer packaged RKE2. C86's "the alias moves" cuts the other way here: every packaged RKE2 carries the same
Cilium.

**What this costs.** Cilium was chosen for **Hubble observability** (C69/C71) — the one feature that pays for
itself on a 3-node fleet. That choice is now blocked by the kernel, not by preference.

The options, none free:

| option | cost |
|---|---|
| **Pin an older kernel on cluster nodes** | yoga runs `linuxPackages_latest` for amdgpu work and carries a patched-kernel specialisation for GPU fault storms (`yoga/default.nix:457-489`). skyspy-dev already pins 6.12 for NVIDIA. Pinning yoga back may cost the GPU work this machine exists for. |
| **Override the Cilium image to a newer release** via the `rke2-cilium` HelmChartConfig | Leaves the version RKE2 tested *and* the airgap image set, which is keyed to the pinned tag. Needs verifying that a newer Cilium's probe passes on 7.2 — untested here. |
| **Switch to canal** | The CNI nixpkgs actually CI-tests (C72), no eBPF probing, no kernel coupling. **Loses Hubble**, which was the entire reason for choosing Cilium. Calico's Goldmane/Whisker (C71) is the partial substitute. |

- **C108.** This is a **decision for the fleet owner**, not an implementation detail. Every option trades
  something already decided.
- **Recorded because of how it was found:** no amount of evaluation, linting or closure-building surfaced it.
  `nix flake check` passed, both host closures evaluated, the module was adversarially reviewed by four
  lenses, and the design survived all of it. It took **booting the cluster**. This is the case for the VM
  gate being load-bearing rather than diligent (C72), and it would otherwise have been discovered by
  deploying to the daily-driver workstation.

### C109 — C73 ANSWERED: strict reverse-path filtering DOES drop cluster traffic [VERIFIED by observation]

C73 kept `checkReversePath` at NixOS's strict default and set `logReversePathDrops = true`, on the explicit
basis that the interaction was *reasoned from a live iptables rule, never observed*, and should be relaxed
only on evidence. **The evidence is in.** From a booting two-node cluster:

```
rpfilter drop: IN=lxc08e3e9a600db SRC=10.42.0.105 DST=9.9.9.9 PROTO=UDP DPT=53
```

**55 drops across four `lxc*` interfaces**, every one with a pod-CIDR source:

| interface | drops | source |
|---|---|---|
| lxc08e3e9a600db | 22 | 10.42.0.105 |
| lxcd62a6786d5e5 | 14 | 10.42.0.205 |
| lxcae3b2c5dcb7e | 9 | 10.42.0.158 |
| lxcecdb99a2b1cf | 8 | 10.42.0.62 |

`lxc*` are Cilium's pod veth devices and `10.42.0.0/16` is the pod CIDR, so this is **pod egress being
dropped by the host firewall** — including DNS to the upstream resolvers C84 configures. It is not the QEMU
slirp noise the earlier run showed (that was `SRC=127.0.0.1` on `eth0`, and remains excluded).

- **C109.** The strict setting is **not viable** as configured. The decision procedure worked exactly as
  intended — it just returned the other answer.
- **The minimal relaxation is `"loose"`, not `false`.** RFC 3704 loose mode accepts a packet when a route back
  exists via *any* interface, which is what pod egress needs, while still rejecting traffic with no return
  path at all. Blanket `false` gives up more than the evidence requires, and C73's reasoning against a
  pre-emptive blanket disable still stands — it is now an *evidenced* narrow relaxation instead.
- Note the module's existing `-net.ipv4.conf.lxc*.rp_filter = 0` does **not** address this: that is the
  **sysctl** mechanism, and these drops come from the `nixos-fw-rpfilter` **iptables mangle chain**. C73
  recorded that they are different mechanisms; this confirms it matters in practice.
- The VM test's scoped rpfilter assertion (which excludes only the two known-benign harness artefacts) is what
  will hold this: it fails on exactly these `lxc*` drops and must not be widened to make a run pass.

### C110 — UNRESOLVED: the panic sysctls hold RKE2's values at runtime despite a correct config

The VM test asserts C76/C77's mitigation and it **fails**. At runtime on a live node:
`kernel.panic=10`, `kernel.panic_on_oops=1`, `vm.overcommit_memory=1` — RKE2's CIS values exactly, and
exactly the contents of `rke2/bundle/share/rke2/rke2-cis-sysctl.conf`.

**The Nix side is provably correct.** `/etc/sysctl.d/60-nixos.conf` in the very system that booted (matched by
`init=` on the kernel cmdline) contains `kernel.panic=0`, `kernel.panic_on_oops=0`, `vm.overcommit_memory=0`,
`vm.panic_on_oom=0`. The `mkForce` merges.

Ruled out, each verified rather than assumed:

- **`systemd-sysctl`** — ran twice, `Result=success`, `ExecMainStatus=0`, no warnings.
- **A competing `sysctl.d` file** — the system has only `50-coredump`, `50-default`,
  `55-nixos-aslr-entropy`, `60-nixos.conf`; `/run/sysctl.d` and `/usr/lib/sysctl.d` do not exist.
- **RKE2** — `kernelRuntimeParameters` carries these exact values but its only consumer is
  `validateKernelReqs`, which **reads**, and only under `--profile=cis`. `cisHardening` is off everywhere and
  there is no `/proc/sys` writer in its tree.
- **k3s's runtime setter** (`pkg/agent/syssetup/setup.go`) — networking keys only: forwarding, bridge-nf,
  conntrack.
- **Cilium's `sysctlfix`** — confirmed DISABLED: the live DaemonSet's init containers are
  `install-portmap-cni-plugin config mount-cgroup mount-bpf-fs clean-cilium-state install-cni-binaries`,
  with no `apply-sysctl-overwrites`.
- **A unit or script in the built system** — nothing in `/etc` references these values, and the rke2 package
  ships no `share/rke2/`.

So a container writes `/proc/sys` directly, after `systemd-sysctl` and unjournalled. **This is left open
rather than guessed at.** It matters because C76 is the highest-hurt finding in the design — on yoga this is
the difference between a GPU oops and a reboot that discards the root filesystem — and the mitigation
currently does not work at runtime.

A diagnostic caveat worth recording: the first version of this dump used `grep -r` over `/etc/sysctl.d/`,
which returned nothing and briefly suggested the keys were absent from the config entirely. NixOS's
`/etc/sysctl.d/*` are **symlinks into the store**, and `grep -r` does not follow symlinks — `-R` does. The
tool was wrong, not the config.

### C111 — C110 ANSWERED: the KUBELET sets them, and C76's mitigation is IMPOSSIBLE [VERIFIED]

The writer is the **kubelet**, and it cannot be stopped.

Kubernetes' `setKernelTunables` (`pkg/kubelet/cm/container_manager_linux.go`) enforces a fixed table at
kubelet startup:

```
vm.overcommit_memory = 1     vm.panic_on_oom      = 0
kernel.panic         = 10    kernel.panic_on_oops = 1
```

— **exactly** the values observed at runtime. Verified by extracting the kubelet out of
`rancher/rke2-runtime:v1.35.7-rke2r1` and reading its strings: `Updating kernel flag`,
`Invalid kernel flag`, `protect-kernel-defaults`, `kernel/panic_on_oops`, `vm/overcommit_memory`.

It writes `/proc/sys` directly, after `systemd-sysctl`, from inside a container — which is why nothing in the
journal, no `sysctl.d` file, and no unit in the built system explained it.

**Both settings of the governing flag lose:**

| `--protect-kernel-defaults` | behaviour |
|---|---|
| `false` (the default) | `KernelTunableModify` — the kubelet **overwrites** our values |
| `true` | `KernelTunableError` — the kubelet **refuses to start** unless they already match |

- **C111.** **A Kubernetes node cannot run with `kernel.panic_on_oops = 0`.** C76's `mkForce` is not
  wrong — it correctly sets the boot-time value, and it still governs while rke2 is stopped — but it cannot
  govern a *running* node. The mitigation for the highest-hurt finding in this design does not exist.
- **What this means for yoga, concretely.** Making yoga a Kubernetes node means accepting
  `kernel.panic_on_oops = 1` and `kernel.panic = 10` on a **daily-driver desktop with a 16 GB tmpfs root**
  that does active amdgpu work. A GPU oops becomes a panic becomes a ten-second reboot, **and that reboot
  discards the root filesystem.** This is not conditional on anything; it is what a kubelet does.
- **This overturns the reasoning behind C93 (host, not guest).** The adversary that killed the guest proposal
  conceded R1 was "genuinely structural" and named re-enabling the amdgpu patched-kernel specialisation as
  the trigger to revisit. That trigger is weaker than the truth: the exposure is **unconditional**, present
  from the first boot as a node, and the four-line `mkForce` that was held up as the cheaper answer **does
  not work**. A guest is the only shape in which the kubelet's tunables land on a kernel that is not the
  workstation's.
- **The VM test asserted something unachievable** and was right to fail. The assertion is corrected to
  encode the mechanism rather than the wish: the values ARE the kubelet's, and C77's fifth-key guard —
  which catches a nixpkgs bump adding a key — stands unchanged and is still the part worth having.

### C112 — DECIDED: yoga keeps `linuxPackages_latest` and accepts the panic exposure

The owner's call, recorded verbatim in effect: *use the latest kernel for yoga, it's ok for now.*

So of C111's three options, the first is taken: **accept it.** yoga stays on `linuxPackages_latest`, remains
the single control-plane node, and runs with the kubelet's `kernel.panic_on_oops = 1` / `kernel.panic = 10`.

What that means, stated once so it is not rediscovered later as a surprise:

- While rke2 is running on yoga, **a kernel oops reboots the machine after ten seconds, and that reboot
  discards the 16 GB tmpfs root.** Anything not declared in `my.system.persistence.features` is gone.
- This is *not* a defect to be fixed later; it is what a kubelet does (C111). The only shapes that avoid it
  are a guest kernel or not making yoga a node.
- **The amdgpu specialisation is the thing to re-examine before re-enabling** (`yoga/default.nix:457-489`,
  currently commented out). It exists to provoke GPU fault storms; doing that on a node carrying
  `panic_on_oops = 1` is qualitatively different from doing it on a workstation. C93's revisit trigger stands,
  and this is what fires it.
- No kernel pinning is needed for Cilium either — the C108 image bridge resolved that on the current kernel,
  so `linuxPackages_latest` costs nothing there.

Consequences carried into the code:

- The module keeps its per-key `mkForce`, which is still correct for the boot-time value and for a host with
  rke2 stopped — but its comment must not claim to protect the workstation, because while the node runs it
  does not.
- The VM test stops asserting a wish. It now encodes the mechanism: the runtime values ARE the kubelet's, and
  a change to that set is what should fail the build. **C77's fifth-key guard is unchanged and remains the
  part worth having** — it catches an upstream module reaching outside its own domain, which was the actual
  bug class.
