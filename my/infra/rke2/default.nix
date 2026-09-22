# RKE2 + Cilium, as this fleet runs it: one always-on server (yoga) and N
# intermittent agents, meeting over the tailnet rather than a shared LAN.
#
# Thin typed wrapper over nixpkgs' services.rke2 -- the same shape my/infra/k3s
# had over services.k3s, and it replaces it. What is NOT thin about it is
# everything below: the upstream module reaches outside its own domain in three
# places (machine-wide panic sysctls, a NetworkManager file that fights the live
# Radicle forge for a shared key, and a unit that starts before the network it
# needs exists), and it declares NO assertions at all, so a misconfigured agent
# builds, switches and never joins behind a warning nixos-rebuild scrolls past.
# Each override here names the constraint it answers in docs/k8s-fleet-constraints.md.
#
# The two numbers to keep straight, because confusing them costs 50 bytes: the
# Cilium `MTU` knob is 1280 (tailscale0's fixed TUN MTU, and the DEVICE MTU),
# and the pod ROUTE MTU it yields is 1230, because getRouteMTU subtracts the
# 50-byte IPv4 VXLAN overhead from whatever is configured. Setting the knob to
# 1230 would yield 1180 (C66). tests/vm-rke2-cluster.nix asserts both.
{ config
, lib
, pkgs
, ...
}:

with lib;

let
  cfg = config.my.infra.rke2;

  isServer = cfg.role == "server";

  # THE PIN, and this file is the one shared place both hosts read (C86).
  # `pkgs.rke2` is `rke2_stable`, an alias the nixpkgs update script MOVES --
  # it read `rke2_1_33` in one tree and `rke2_1_35` in the pinned one. skyspy-dev
  # is away for months at a time and would come back rebuilt against whatever
  # the alias had become; an agent newer than its server does not join. Pinning
  # per host would be the same bug with extra steps.
  rke2Package = pkgs.rke2_1_35;

  # The upstream unit name: `rke2-server` or `rke2-agent` (rancher/rke2.nix:11).
  serviceName = "rke2-${cfg.role}";

  # The token as a FILE, never as a string. sops-nix delivers it at a runtime
  # path, mode 0400 root-owned, because systemd reads credential sources as root
  # before any User= drops privileges (C30). The `or` fallback is the idiom
  # my/infra/radicle uses: the same value on a real host, and readable in tests
  # that mkForce the sops set away.
  tokenPath =
    if cfg.tokenFile != null then
      cfg.tokenFile
    else
      (config.sops.secrets.${cfg.tokenSecret} or { path = "/run/secrets/${cfg.tokenSecret}"; }).path;

  # The airgap image set, keyed on the platform rather than named literally
  # (C40). A module that writes `images-core-linux-amd64-tar-zst` outright
  # produces a system that cannot be built for the other architecture, and the
  # error arrives as a missing attribute on the SECOND host, not the first. The
  # `or (throw ...)` is nixpkgs' own idiom from nixos/tests/rancher/default.nix.
  #
  # Both roles need them: an agent runs the same core components' images and the
  # same cilium DaemonSet. The URLs are pinned to the release tag and hashed, so
  # nothing is fetched at activation (C50).
  # ---------------------------------------------------------------------------
  # C108 BRIDGE -- DELETE WHEN v1.19.8 SHIPS, OR WHEN RKE2 PINS A FIXED CHART.
  #
  # The Cilium RKE2 pins (1.19.601 = v1.19.6) CANNOT START on this fleet's kernel.
  # Linux 7.2 tightened bpf_set_retval()'s argument check (torvalds/linux
  # b1f7f67b74c2, v7.2-rc1); Cilium's feature probe passes the ctx POINTER in R1;
  # the verifier now rejects it, and pkg/datapath/linux/probes/probes.go returns
  # cleanly only for ebpf.ErrNotSupported -- every other error is logging.Fatal.
  # So cilium-agent crash-loops on both nodes with
  #   level=fatal msg="failed to probe helper" ... "R1 is not a scalar"
  # and no flag, config key or chart value turns it off. Found by BOOTING the
  # cluster in tests/vm-rke2-cluster.nix; nix flake check, both host closures and
  # four adversarial review passes all went green over it.
  #
  # Upstream deleted the probe (cilium/cilium#48016) and it landed on branch v1.19
  # on 2026-09-01. Verified by reading the header out of the image below rather
  # than by trusting a changelog: try_set_retval() now guards on
  # bpf_core_enum_value_exists(...) with no #ifdef HAVE_SET_RETVAL, so there is no
  # probe program left for the verifier to reject.
  #
  # Bumping RKE2 does NOT fix this -- every packaged release, master included,
  # pins the same 1.19.601 chart. The fix is +8/-12 across bpf/ headers and
  # probes.go: no chart template, no ConfigMap key, no CLI flag, which is why
  # overriding the IMAGE alone is sufficient and nothing rides along.
  #
  # These are dockerTools.pullImage FODs, which is nixpkgs' own documented idiom
  # for services.rke2.images. The pull happens at NIX BUILD TIME and is
  # digest-pinned, so this stays airgap-clean at activation (C50) -- arguably more
  # reproducible than RKE2's own tarball, not less.
  #
  # THE COST, stated plainly: cilium-ci:<sha> is a CI artifact off the release
  # branch. No release testing, no CVE-scan promise. That is the trade for keeping
  # Hubble -- the only reason this CNI was chosen -- on the fleet's kernel.
  ciliumFixRef = "a4def6359a72545b687c987e1284e202ff077aa5";
  ciliumFixImage =
    { repo, digest, hash }:
    pkgs.dockerTools.pullImage {
      imageName = "quay.io/cilium/${repo}";
      imageDigest = digest;
      inherit hash;
      os = "linux";
      arch = "amd64";
      finalImageName = "quay.io/cilium/${repo}";
      finalImageTag = ciliumFixRef;
    };
  ciliumFixImages = map ciliumFixImage [
    {
      repo = "cilium-ci";
      digest = "sha256:4ba64fac78186f7be0f5cc6bee780cadcad314944f87016cc886e49c762ba96d";
      hash = "sha256-heGiENBlrX79mhQfOGKG/0wl2om7II8UyzbRKuVwv3o=";
    }
    {
      repo = "operator-generic-ci";
      digest = "sha256:03f1583e7529f084a103297e73efc7e7151a18ba3b1b87aeeefb4222f994a961";
      hash = "sha256-vM7WUnXXhr9eBZpg3tNL+RRjQdx1dH76GlHeWL06EP8=";
    }
    # The relay is here rather than deferred on purpose: the Hubble subtest runs
    # on every VM run regardless, and a v1.19.6 relay against fixed agents makes a
    # failure ambiguous between "the fix did not work" and "version skew".
    {
      repo = "hubble-relay-ci";
      digest = "sha256:a290c36fc4e7ef7aa9b16676a02b7541d229cbe71c91083031b8eb74268ab09d";
      hash = "sha256-uMWMZSu294Z2Hwt6UvNBztjuq5Wv1SyfU3bJ2fCksdU=";
    }
  ];

  airgapImages =
    {
      # The FODs are amd64-only, matching their pinned hashes. aarch64 keeps the
      # stock set: nothing on this fleet builds it yet (the Mac VM node is
      # deferred), and an arm64 node would need its own digests and its own proof
      # that the fix is in that build.
      x86_64-linux = (with rke2Package; [
        images-core-linux-amd64-tar-zst
        images-cilium-linux-amd64-tar-zst
      ]) ++ ciliumFixImages;
      aarch64-linux = with rke2Package; [
        images-core-linux-arm64-tar-zst
        images-cilium-linux-arm64-tar-zst
      ];
    }.${pkgs.stdenv.hostPlatform.system}
      or (throw "my.infra.rke2: unsupported system ${pkgs.stdenv.hostPlatform.system}; RKE2 ships airgap images for x86_64-linux and aarch64-linux only.");

  # Cluster DNS must not share a failure domain with the dataplane (C84).
  resolvConfName = "rke2-resolv.conf";
  resolvConfFile = "/etc/${resolvConfName}";

  # Cilium's device names are CONSTANTS (cilium/pkg/defaults/node.go:21, :24,
  # :36, :72), not derived from anything, so hardcoding them is reading the
  # source rather than guessing. `lxc+` is iptables' wildcard -- `lxc*` is a
  # shell glob, would match nothing, and would fail silently, which is exactly
  # the shape C22 exists to catch.
  ciliumInterfaces = [ "cilium_host" "cilium_net" "cilium_vxlan" "lxc+" ];

  # Node-to-node ports, from docs/rke2-cluster.md's table. 9345 is the one people
  # forget: it is the supervisor, the registration endpoint an agent dials before
  # it has any kubeconfig, and a node that reaches 6443 but not 9345 never joins
  # with a failure that reads as an authentication problem.
  #
  #   10250  kubelet, every node        dialled by the server
  #   4240   cilium cluster health      dialled by peer cilium-agents
  #   4244   Hubble server, every node  dialled by hubble-relay
  #   6443   kube-apiserver             server only
  #   9345   supervisor + static charts server only
  #   8472   cilium VXLAN tunnel (UDP)  peer nodes
  #
  # Not opened anywhere: 2379/2380 (etcd, one member and no peer), 4245
  # (hubble-relay is a ClusterIP, reached over the pod network), the metrics
  # ports (no Prometheus on this fleet yet), and the control-plane health ports
  # (localhost probes).
  clusterTCPPorts = [ 10250 4240 4244 ] ++ optionals isServer [ 6443 9345 ];
  clusterUDPPorts = [ 8472 ];

  # The readiness condition rke2 actually needs, which is NOT the same as
  # `tailscaled.service` having started (C65). Four things are computed in that
  # window -- --node-ip, the apiserver advertise address, kubelet registration
  # and an agent's serverAddr -- so this is one fix for four symptoms.
  #
  # When nodeIP is set the wait is for exactly that address; otherwise for any
  # address out of 100.64.0.0/10, the CGNAT range Tailscale allocates node
  # addresses from. IPv4 only, because the cluster is single-stack IPv4.
  tailnetAddressPattern =
    if cfg.nodeIP != null then
      "inet ${escapeRegex cfg.nodeIP}/"
    else
      "inet 100\\.(6[4-9]|[7-9][0-9]|1[01][0-9]|12[0-7])\\.";

  tailnetAddressDescription =
    if cfg.nodeIP != null then "my.infra.rke2.nodeIP (${cfg.nodeIP})" else "a 100.64.0.0/10 address";

  # Bounded, not infinite. The upstream unit sets TimeoutStartSec = 0, so an
  # unbounded wait would sit in `activating` forever and report nothing; a
  # bounded one fails the unit with a sentence, and Restart=always (upstream,
  # RestartSec=5s) retries until the tailnet is up.
  tailnetWaitSeconds = 120;

  waitForTailnetAddress = pkgs.writeShellScript "rke2-wait-for-tailnet-address" ''
    set -eu

    deadline=$((SECONDS + ${toString tailnetWaitSeconds}))
    while ! ${pkgs.iproute2}/bin/ip -4 -o addr show scope global |
      ${pkgs.gnugrep}/bin/grep -qE '${tailnetAddressPattern}'; do
      if [ "$SECONDS" -ge "$deadline" ]; then
        echo "rke2: ${tailnetAddressDescription} is still absent after ${toString tailnetWaitSeconds}s." >&2
        echo "rke2 is not started without it: --node-ip, the apiserver advertise" >&2
        echo "address, kubelet registration and an agent's --server all resolve" >&2
        echo "wrongly or not at all while the tailnet address is missing." >&2
        exit 1
      fi
      ${pkgs.coreutils}/bin/sleep 2
    done
  '';
in
{
  config = mkIf cfg.enable (mkMerge [
    {
      # ---------------------------------------------------------------------
      # The join contract, enforced at EVAL time.
      #
      # `services.rke2` declares no assertions at all -- the only `assertions`
      # in nixos/modules/services/cluster/rancher/ is on the k3s path
      # (k3s.nix:125). The serverAddr and token checks it does carry are
      # `warnings`, phrased "should", so a misconfigured agent builds, switches
      # and fails at runtime (C88). C11 requires joining to be declarative and
      # idempotent; until these exist there is no eval-time enforcement of that
      # anywhere.
      # ---------------------------------------------------------------------
      assertions = [
        {
          # Found by the VM test on its first run, which is the only thing that
          # could have found it: `--disable` is a SERVER flag, the rke2 agent
          # subcommand does not define it, and nixpkgs appends it to ExecStart for
          # BOTH roles (rancher/default.nix:940) while only WARNING that an agent
          # should not set it (:811). The agent therefore builds, switches, starts,
          # and dies on its first line with
          #   level=fatal msg="Error: flag provided but not defined: -disable"
          # -- a node that never joins, behind a warning nixos-rebuild scrolls past.
          # Same shape as C88's serverAddr/token warnings, same answer.
          assertion = cfg.role == "agent" -> config.services.rke2.disable == [ ];
          message = ''
            services.rke2.disable is set on a node whose my.infra.rke2.role = "agent".

            `--disable` exists only on the server subcommand. nixpkgs appends it to
            the ExecStart of both roles and merely warns, so this builds and
            switches cleanly and then the agent exits 1 at startup:

              level=fatal msg="Error: flag provided but not defined: -disable"

            Set it on the server node only. What a server disables is a property of
            the cluster, not of each machine in it.
          '';
        }
        {
          # C24/C82. Without --node-ip the kubelet advertises whatever carries the
          # default route -- on skyspy-dev, whatever cafe wifi it is attached to,
          # and the cluster then records a node address that is neither stable nor
          # on the tailnet. The readiness wait does not catch it either: it
          # degrades to "any 100.64.0.0/10 address", which tailscaled supplies
          # regardless. So a null here is a silently wrong cluster, not a failure.
          assertion = cfg.nodeIP != null;
          message = ''
            my.infra.rke2.nodeIP is null.

            Set it to this node's tailnet address. Left unset, rke2 omits
            --node-ip and the kubelet advertises the interface holding the
            default route, which on a laptop is whatever network it happens to be
            on. Nodes must address each other over the tailnet (C24/C82), and
            nothing downstream reports the mistake -- the node registers, goes
            Ready, and is simply unreachable from its peers.
          '';
        }
        {
          assertion = cfg.role == "agent" -> cfg.serverAddr != "";
          message = ''
            my.infra.rke2.role = "agent" with no serverAddr.

            services.rke2 only WARNS about this (rancher/default.nix:827), so the
            node would build, switch, and never join. Point it at the server's
            supervisor by literal tailnet IP -- port 9345, not 6443, and an IP
            rather than a MagicDNS name because tailscaled's resolver is not up
            when rke2 starts (C82):

              my.infra.rke2.serverAddr = "https://100.97.96.49:9345";
          '';
        }
        {
          assertion = cfg.tokenFile == null -> config.my.secrets.enable;
          message = ''
            my.infra.rke2 needs a join token and takes it from sops.

            Set my.secrets.enable = true (the module then declares
            sops.secrets.${cfg.tokenSecret} at mode 0400 and reads its runtime
            path), or name another delivery with my.infra.rke2.tokenFile.

            It is a FILE either way: services.rke2.token renders `--token <value>`
            into the unit, and the unit is a store path -- world-readable,
            permanent, and carried along by nix copy (C27, C29).
          '';
        }
        {
          assertion = isServer -> cfg.tlsSan != [ ];
          message = ''
            my.infra.rke2.role = "server" with an empty tlsSan.

            THIS IS THE ONE THING A REBUILD CANNOT FIX. The serving certificate
            is generated once, at first start, and then persisted, and
            --tls-san-security defaults to true -- so a name missing at that
            moment cannot be added by changing the configuration and rebuilding.
            It takes imperative surgery against persisted state (C78).

            List every name a peer might use: the MagicDNS name, the short
            hostname, and the tailnet IP that serverAddr will literally be.
          '';
        }
        {
          assertion = isServer -> cfg.cni != null;
          message = ''
            my.infra.rke2.role = "server" with cni = null.

            A server is what deploys the CNI, as an RKE2 packaged chart. With no
            CNI every pod stays ContainerCreating and the cause is one line in
            the kubelet's log.
          '';
        }
        {
          assertion = cfg.role == "agent" -> cfg.cni == null;
          message = ''
            my.infra.rke2.cni is set on an agent.

            The CNI is installed from the SERVER's manifests; setting it here is
            a no-op that reads as configuration (rancher/rke2.nix:127-129 warns
            about the same thing).
          '';
        }
        {
          # The world triad is the last octal digit. Type-checking a mode string
          # is not what this catches -- what it catches is 0644, which is what
          # the module this replaces set, from a oneshot, driven by an option
          # that defaulted to true.
          assertion = hasSuffix "0" cfg.kubeconfigMode;
          message = ''
            my.infra.rke2.kubeconfigMode = "${cfg.kubeconfigMode}" has a world bit.

            /etc/rancher/rke2/rke2.yaml embeds the cluster-admin client
            certificate AND its private key. A world bit grants full,
            unauthenticated, unaudited cluster-admin to every local account and
            every process on the host -- a browser, a language server, a CI job
            (C43). C44 allows 0600 root-only, or 0640 with a declared group
            through kubeconfigGroup, and nothing looser.
          '';
        }
        {
          assertion = cfg.upstreamNameservers != [ ];
          message = ''
            my.infra.rke2.upstreamNameservers is empty.

            ${resolvConfFile} would carry no nameserver at all, and CoreDNS
            crash-loops on a resolv.conf with none. The point of the file is that
            cluster DNS does not forward through the MagicDNS stub, whose daemon's
            failure mode is "restart it" (C84) -- not that it forwards nowhere.
          '';
        }
      ];

      # Root-owned, mode 0400. DECLARED ONLY when sops is the delivery
      # mechanism: sops-nix runs sops-install-secrets whenever any secret
      # exists, and that tool mounts a ramfs, which needs CAP_SYS_ADMIN -- so on
      # a machine that has not got it, declaring a secret is by itself the
      # difference between activation succeeding and failing (C31).
      sops.secrets = mkIf (cfg.tokenFile == null) {
        ${cfg.tokenSecret} = { mode = "0400"; };
      };

      services.rke2 = {
        enable = true;
        package = rke2Package;
        inherit (cfg) role nodeName nodeIP serverAddr cni;
        tokenFile = tokenPath;
        images = airgapImages;

        # C87. The unit sets KillMode = process, deliberately leaving containerd
        # and every pod running when it stops; graceful node shutdown is the
        # kubelet's half of ending that tidily, and rke2-killall below is the
        # host's half.
        gracefulNodeShutdown.enable = true;

        extraFlags = [
          # C84: kubelet's resolv.conf, carrying real upstream resolvers rather
          # than the MagicDNS stub every pod would otherwise inherit.
          "--resolv-conf=${resolvConfFile}"
        ];
      };

      # C64/C74: ONE OWNER FOR `unmanaged-devices`, AND IT IS NOT THIS MODULE.
      #
      # nixpkgs' rke2 module writes NetworkManager/conf.d/rke2-canal.conf setting
      # the same key my/system/core/default.nix already owns. NetworkManager
      # reads conf.d in lexical order and a later file wins for one key; 'r' is
      # 0x72 and '9' is 0x39, so rke2-canal.conf sorts LAST and silently drops
      # core's podman*/docker*/br-* exclusions -- the ones that keep
      # NetworkManager's hands off the RUNNING Radicle forge. NetworkManager
      # would then run DHCP on podman0 and can take it down under a live
      # container, and the failure would look like a Radicle problem.
      #
      # mkForce because upstream's value is a plain expression, not a mkDefault
      # (rancher/rke2.nix:134). Cilium's interface names are contributed to
      # core's file instead, where the single owner already is.
      environment.etc = {
        "NetworkManager/conf.d/rke2-canal.conf".enable = mkForce false;

        # The kubelet's resolv.conf (C84). Store-backed, so cluster DNS has no
        # runtime dependency on anything -- least of all on tailscaled, whose
        # MagicDNS stub every pod would otherwise inherit as its upstream.
        ${resolvConfName}.text =
          concatMapStrings (ns: "nameserver ${ns}\n") cfg.upstreamNameservers;
      };

      boot.kernel.sysctl = {
        # C76/C77 -- THE HIGHEST-HURT ITEM IN THE WHOLE ANALYSIS, and it has
        # nothing to do with Kubernetes.
        #
        # `services.rke2.enable = true` writes these four machine-wide
        # (rancher/rke2.nix:144), INSIDE `mkIf cfg.enable` and OUTSIDE the
        # cisHardening guard that starts at :151 -- so every host that enables
        # RKE2 gets them whether or not it asked for CIS hardening. yoga is a
        # daily-driver Hyprland desktop running amdgpu whose root is a 16 GB
        # tmpfs: kernel.panic_on_oops = 1 turns a GPU oops into a panic and
        # kernel.panic = 10 reboots ten seconds later, AND THAT REBOOT DISCARDS
        # THE ROOT FILESYSTEM. The blast radius is the workstation, not the
        # cluster.
        #
        # PER KEY, never by replacing the attrset: a future nixpkgs bump that
        # adds a fifth key must surface as a visible change rather than be
        # swallowed by a wholesale override. mkForce rather than mkDefault
        # because upstream's are plain values -- anything else is a definition
        # conflict, not a merge.
        #
        # WHAT THIS DOES NOT DO, and the comment above used to imply it did:
        # it does NOT keep panic_on_oops = 0 on a RUNNING node. Kubernetes'
        # setKernelTunables rewrites all four at kubelet startup -- directly into
        # /proc/sys, from inside a container, after systemd-sysctl -- and there is
        # no way out: --protect-kernel-defaults=false (the default) makes the
        # kubelet overwrite them, and =true makes it refuse to start unless they
        # already match. Verified by reading the kubelet out of
        # rancher/rke2-runtime (C111).
        #
        # So this governs the BOOT-TIME value and a host with rke2 stopped, and
        # that is all. The fleet has accepted the running-node exposure (C112):
        # on yoga, whose root is a 16 GB tmpfs, a kernel oops reboots in ten
        # seconds and the root is discarded. Re-enabling the amdgpu
        # patched-kernel specialisation -- which exists to PROVOKE fault storms --
        # is the thing to reconsider before doing, not this override.
        "kernel.panic" = mkForce 0;
        "kernel.panic_on_oops" = mkForce 0;
        "vm.panic_on_oom" = mkForce 0;
        "vm.overcommit_memory" = mkForce 0;

        # The other half of turning `sysctlfix` off in the Cilium values below
        # (C68): the same keys its init container would have written to
        # /etc/sysctl.d/99-zzz-override_cilium.conf before nsenter-ing PID 1's
        # mount namespace and restarting systemd-sysctl. Declaring them here
        # moves a host mutation into the configuration that owns host mutations;
        # dropping them along with the writer would leave mangled packets being
        # dropped on Cilium's own devices.
        #
        # The leading `-` is systemd-sysctl's "ignore if absent": these are glob
        # patterns and match nothing until Cilium creates the devices.
        # NOTE this is the rp_filter SYSCTL, a different mechanism from
        # networking.firewall.checkReversePath, which stays at NixOS's strict
        # default (C73).
        "-net.ipv4.conf.lxc*.rp_filter" = mkDefault 0;
        "-net.ipv4.conf.cilium_*.rp_filter" = mkDefault 0;
        "net.ipv4.conf.all.rp_filter" = mkDefault 0;
      };

      # C21/C46: SCOPED TO THE TAILNET, never fleet-wide. The module this
      # replaces wrote `networking.firewall.allowedTCPPorts = [ cfg.apiPort ]`,
      # which on skyspy-dev offers the Kubernetes API to whatever cafe wifi the
      # laptop is attached to. Written as the plain NixOS option rather than
      # through my.network.tailscale.allowedTCPPorts, following
      # my/network/openssh: one rule for "a feature contributes its own port".
      networking.firewall = {
        interfaces.tailscale0 = {
          allowedTCPPorts = clusterTCPPorts;
          allowedUDPPorts = clusterUDPPorts;
        };

        # C109: "loose", and this is an EVIDENCED relaxation rather than a
        # cargo-culted one.
        #
        # C73 deliberately kept NixOS's strict default and turned on
        # logReversePathDrops, on the grounds that the interaction had been
        # reasoned from a live iptables rule but never observed, and that a
        # security regression adopted for a feature nobody uses is a giveaway
        # rather than a trade. The VM test then observed it: 55 drops across four
        # of Cilium's `lxc*` pod veths, every one with a pod-CIDR source,
        # including pod DNS to the upstream resolvers C84 configures --
        #   rpfilter drop: IN=lxc08e3e9a600db SRC=10.42.0.105 DST=9.9.9.9 DPT=53
        # Pod egress does not survive strict mode.
        #
        # `loose` (RFC 3704) accepts a packet when a route back exists via ANY
        # interface, which is what an overlay's asymmetric paths need, while still
        # rejecting traffic with no return path at all. `false` would give up more
        # than the evidence asks for, on the node that publishes services to the
        # tailnet.
        #
        # NOT the same mechanism as the rp_filter SYSCTLS above: those are the
        # per-interface kernel knobs, this is the nixos-fw-rpfilter iptables
        # mangle chain. Setting one does nothing for the other, which is exactly
        # how this stayed hidden until a cluster actually ran.
        checkReversePath = mkForce "loose";

        # ...and Cilium's OWN devices are exempted outright, because `loose` is
        # not enough for all of it. Measured: strict dropped 55 packets across
        # four `lxc*` pod veths; `loose` cleared those and left 12 on
        # `cilium_net` -- same-node pod-to-pod on Cilium's host-side veth pair.
        #
        # `trustedInterfaces` cannot fix this and it is worth writing down why:
        # that option acts on the filter table's input chain, while
        # `nixos-fw-rpfilter` is a mangle PREROUTING chain that runs BEFORE any
        # of it. So the interfaces are trusted and their packets are still
        # dropped, which is precisely the kind of "I configured that already"
        # that costs an afternoon.
        #
        # Exempting these four is narrow: they are devices Cilium creates and
        # owns, carrying traffic Cilium itself policies. Every other interface --
        # including the tailnet and the LAN -- keeps loose reverse-path checking.
        # ip46tables, not iptables: NixOS builds nixos-fw-rpfilter for BOTH
        # families, and a v4-only exemption leaves the v6 chain dropping. The
        # first attempt here did exactly that and the run came back with two
        # survivors -- ICMPv6 type 143 (MLD report) and 133 (router
        # solicitation) from a pod's link-local address on an lxc veth. Harmless
        # IPv6 housekeeping on a single-stack IPv4 cluster, but the assertion is
        # deliberately "zero cluster drops", and moving the goalposts to exclude
        # them would blunt the one check that caught all of this.
        extraCommands = ''
          for dev in cilium_host cilium_net cilium_vxlan "lxc+"; do
            ip46tables -t mangle -I nixos-fw-rpfilter -i "$dev" -j RETURN
          done
        '';
        extraStopCommands = ''
          for dev in cilium_host cilium_net cilium_vxlan "lxc+"; do
            ip46tables -t mangle -D nixos-fw-rpfilter -i "$dev" -j RETURN 2>/dev/null || true
          done
        '';

        # C22: trustedInterfaces follows the CNI ACTUALLY IN USE. The module
        # this replaces hardcoded flannel's cni0/flannel.1; under Cilium those
        # never appear, the real ones are untrusted, and pod traffic is dropped
        # by the host firewall with nothing in any log naming the cause.
        trustedInterfaces = ciliumInterfaces;
      };

      systemd = {
        services = {
          # C65: rke2 must not start before the tailnet exists. The shared
          # rancher unit orders only on firewall.service and
          # network-online.target (rancher/default.nix:909-916), and neither
          # implies a tailnet address.
          ${serviceName} = {
            after = [ "tailscaled.service" ];
            wants = [ "tailscaled.service" ];
            serviceConfig.ExecStartPre = [ waitForTailnetAddress ];
          };

          # C87: the unit sets KillMode = process, deliberately leaving
          # containerd and every pod running when it stops -- and the pod mounts
          # nested beneath the kubelet directory are what block unmounting
          # /persist at shutdown. A blocked unmount does not fail, it HANGS
          # until systemd's stop timeout force-kills it, which is why the VM
          # test asserts a clean reboot on the clock rather than on an exit
          # status.
          #
          # Default dependencies are deliberately left ON: that is what puts the
          # ExecStop in the ordinary stop-all-services phase, which systemd
          # already guarantees precedes tearing down local-fs.target and the
          # mounts beneath it. Before = umount.target states the intent as well.
          rke2-killall = {
            description = "Tear down rke2's containers and mounts before the filesystems go";
            wantedBy = [ "multi-user.target" ];

            # BEFORE the rke2 unit, not after, and the difference is the whole
            # point. Stop ordering is the INVERSE of start ordering
            # (systemd.unit(5)), so `after = [ rke2 ]` stops this unit FIRST --
            # and its ExecStop opens with `systemctl stop rke2-server.service`
            # (rke2-killall.sh:58), which then blocks on a stop job queued behind
            # the very unit doing the blocking. `systemctl stop` waits, the
            # request merges into the pending job rather than erroring, and
            # `|| true` catches exit status, not blocking. At TimeoutStopSec the
            # ExecStop is killed on its FIRST line, so the unmounts (:63-65), the
            # `ip link delete` of the CNI interfaces (:70-78) and the iptables
            # restore never run -- every shutdown costs the full timeout AND
            # leaves behind exactly the pod mounts under /var/lib/kubelet that
            # this unit exists to clear.
            before = [ "${serviceName}.service" "umount.target" ];

            # ExecStop here is DESTRUCTIVE: it SIGKILLs every shim and does
            # `umount && rm -rf --one-file-system` over /var/lib/kubelet/pods,
            # which on an impermanent host is inside the persisted tree. A
            # oneshot with RemainAfterExit is `active`, and this unit embeds
            # several store paths, so ANY nixpkgs bump changes it and
            # switch-to-configuration would stop-then-start it -- running that
            # teardown during an ordinary `nixos-rebuild switch`, then NOT
            # restarting rke2 (it did not itself change), so the cluster stays
            # down while the switch reports success.
            #
            # stopIfChanged = false is NOT sufficient: it routes the unit to
            # units_to_restart, and a restart still runs ExecStop. Precedent for
            # this shape: nixos/modules/config/swap.nix.
            #
            # This pairs with the `before` above and must not be separated from
            # it. The inverted ordering was MASKING this, because the deadlock
            # meant the teardown never actually executed. Fixing either alone
            # turns a slow shutdown into a rebuild that wipes pod state.
            restartIfChanged = false;

            serviceConfig = {
              Type = "oneshot";
              RemainAfterExit = true;
              ExecStart = "${pkgs.coreutils}/bin/true";
              ExecStop = "${rke2Package}/bin/rke2-killall.sh";
              # Bounded on purpose: a killall that hangs must not become the
              # shutdown hang it exists to prevent.
              TimeoutStopSec = "30s";
            };
          };
        };

        # C85: my/system/core sets oomd.enableRootSlice = true unconditionally,
        # and kubepods.slice is a direct child of the cgroup root -- so every pod
        # is an oomd kill candidate from day one, on a machine whose 16 GB tmpfs
        # root competes with a 28 GB /tmp. A SIGKILLed cilium-agent is a
        # whole-node network outage that reads as a Cilium bug, and every hour
        # spent debugging Cilium is wasted.
        #
        # The narrow shape of the two C85 offers: it scopes the exception to the
        # cluster and names what is being protected, rather than backing out a
        # deliberate fleet-wide setting for the desktop workloads it was turned
        # on for. As a DROP-IN, not a unit: kubepods.slice is created by the
        # kubelet at runtime, and a static unit file of that name would be a
        # second, competing definition of it.
        slices.kubepods = {
          description = "Kubernetes pods, deprioritised for systemd-oomd";
          overrideStrategy = "asDropin";
          sliceConfig.ManagedOOMPreference = "avoid";
        };
      };

      # ---------------------------------------------------------------------
      # PERSISTENCE (C59, C60, C80, C81, C92): one contribution point, terms
      # gated per role, following the forge (my/infra/radicle/default.nix:399).
      # A directory is persisted IFF the thing that owns it is enabled -- an
      # unconditional flat list persists directories for services that are off,
      # and an empty persisted directory is indistinguishable from a service
      # that failed to write.
      #
      # SURGICAL, not the state root. `manifests`, `images`, `charts` and the
      # containerd config template are rendered as systemd-tmpfiles `L+`
      # SYMLINKS INTO /nix/store, under paths inside the state root
      # (rancher/default.nix:849, :856, :871, :879). `L+` creates or replaces a
      # symlink; it never PRUNES one whose declaration has gone away. Persist
      # /var/lib/rancher wholesale and every manifest ever declared leaves a link
      # in /persist pointing at a store path that will eventually be
      # garbage-collected -- which RKE2's deploy controller keeps trying to
      # apply, from a dangling link, with nothing naming the cause (C80).
      #
      # Never persisted, for that reason and the ones after it:
      #   .../server/manifests, .../agent/images, .../server/static/charts,
      #   .../agent/etc              -- all `L+` symlinks into the store
      #   .../agent/pod-manifests    -- control-plane static pods, rewritten from
      #                                 config every start; a persisted stale one
      #                                 SURVIVES THE REBUILD MEANT TO REMOVE IT
      #   .../server (the parent)    -- accumulates tls-<unixtime> cluster-reset
      #                                 backups that are never pruned
      #   /etc/rancher (the parent)  -- rke2.yaml is rewritten every start, and
      #                                 persisting it drags the ADMIN KUBECONFIG
      #                                 into /persist, which kubeconfigMode above
      #                                 exists to keep out of reach
      #   .../agent/*.{crt,key,kubeconfig}
      #                              -- re-requested from the server and
      #                                 overwritten unconditionally every start;
      #                                 not identity (C91)
      # ---------------------------------------------------------------------
      my.system.persistence.features.systemDirectories =
        [
          # Node identity, half one: the password the server checks at EVERY
          # re-registration. Persist both halves or neither -- persisting one is
          # broken on every boot, because the server remembers a password the
          # node no longer has, and it fails at re-registration rather than at
          # boot so it reads as a network problem (C81). It is a directory, not
          # a file, which is why the missing `systemFiles` option never applied.
          "/etc/rancher/node"

          # The kubelet's client certificate, pods/ volume mounts, plugin and
          # device-plugin sockets. Losing it files a fresh CSR every boot and
          # hands any hostPath volume back empty, with no error.
          "/var/lib/kubelet"

          # The containerd content store. On a tmpfs root every image pulled
          # after a reboot is resident RAM competing with the 28 GB /tmp on the
          # same machine -- a memory-exhaustion path, not a slow start. The repo
          # already persists rootless podman's store for the same reason.
          "/var/lib/rancher/rke2/agent/containerd"

          # The rke2-runtime image, re-extracted at every start of BOTH roles,
          # with .../rke2/bin symlinked at it. nixpkgs' no_stage build tag does
          # not disable this (C92).
          "/var/lib/rancher/rke2/data"
        ]
        ++ optionals isServer [
          # Node identity, half two, and more: the datastore AND the
          # authoritative copy of the cluster CA, which server/tls and
          # server/cred are reconciled FROM at every start. That is what makes
          # "a regenerated CA is a different cluster wearing the old hostname"
          # true. WHOLE, never db/etcd alone: a missing db/etcd/name sets
          # clusterReset = true on every boot (C92, C94).
          "/var/lib/rancher/rke2/server/db"
          "/var/lib/rancher/rke2/server/cred"
          "/var/lib/rancher/rke2/server/tls"
        ];
    }

    # -----------------------------------------------------------------------
    # Server-only. Every flag below is a SERVER flag: rke2's agent command does
    # not define --disable, --tls-san or --write-kubeconfig-*, and passing one
    # to an agent is a start-up failure at flag parsing, not a warning.
    # -----------------------------------------------------------------------
    (mkIf isServer {
      services.rke2 = {
        # C83: rke2-ingress-nginx is patched into a hostNetwork-shaped DaemonSet
        # claiming 80 and 443 on every node it lands on, and `tailscale serve`
        # already holds :443 on yoga's tailnet address for the Radicle explorer.
        # Whichever binds first wins, and if nginx wins the explorer stops
        # answering with nothing logging a conflict. Cluster services are fronted
        # with `tailscale serve` against their ClusterIPs instead, which keeps
        # one owner for :443.
        disable = [ "rke2-ingress-nginx" ];

        # C78: there is no nixpkgs option for --tls-san, and the SAN list must be
        # complete before the cluster first starts. C43/C44: the kubeconfig mode
        # is a flag, not a chmod from a oneshot -- RKE2 applies it where it
        # writes the file, so there is no window in which the file is 0644.
        extraFlags =
          map (san: "--tls-san=${san}") cfg.tlsSan
          ++ [ "--write-kubeconfig-mode=${cfg.kubeconfigMode}" ]
          ++ optional (cfg.kubeconfigGroup != null) "--write-kubeconfig-group=${cfg.kubeconfigGroup}";

        # THE WHOLE CNI CONFIGURATION MECHANISM. RKE2 deploys the CNI as a
        # packaged Helm chart, and the supported way to change a packaged
        # chart's values is a HelmChartConfig dropped into the server's
        # manifests directory -- there is no flag, and nixpkgs' own RKE2 test
        # says so in a comment (nixos/tests/rancher/multi-node.nix:110-114).
        #
        # The attribute must NOT be named `*.yaml`: rke2 opens .yaml/.yml
        # manifests O_RDWR, which a read-only store path cannot serve, so the
        # nixpkgs module sets jsonManifests for RKE2 and derives the suffix from
        # this name (rancher/rke2.nix:24-27, rancher/default.nix:34-41).
        # `rke2-cilium-config` becomes rke2-cilium-config.json, which is right.
        manifests.rke2-cilium-config.content = {
          apiVersion = "helm.cattle.io/v1";
          kind = "HelmChartConfig";
          metadata = {
            name = "rke2-cilium";
            namespace = "kube-system";
          };
          # spec.valuesContent is a STRING, either JSON or YAML.
          spec.valuesContent = builtins.toJSON {
            # The DEVICE MTU (C66). 1280 is tailscale0's fixed TUN MTU and the
            # IPv6 minimum, and getRouteMTU subtracts the 50-byte IPv4 VXLAN
            # overhead from it to give the pod ROUTE MTU of 1230 that the VM
            # test asserts. Setting this to 1230 would yield 1180.
            #
            # Pinned for DETERMINISM across three differently-shaped machines,
            # not because autodetection computes the wrong answer: RKE2's fork
            # sets cni.chainingMode = portmap, and Cilium refuses to register the
            # endpoint-MTU updater under any chaining mode but "none", so a
            # recomputed MTU never reaches running pods -- and the pods that
            # would miss it are exactly the boot-time system pods.
            MTU = 1280;

            # C69: RKE2's fork ships Hubble DISABLED. Hubble is the entire reason
            # this CNI was chosen, so this is not optional -- Cilium alone buys
            # no observability at all until this lands. relay aggregates the
            # per-node Hubble servers into one `hubble observe`; without it
            # Hubble is a per-node socket.
            # C108 BRIDGE. `image.override` short-circuits the chart's whole
            # repository/tag/digest/suffix construction, so it is the one key that
            # cleanly substitutes a build RKE2 did not pin. RKE2's own patch sets
            # useDigest = false, which is what lets a tag win here at all, and
            # every pullPolicy is IfNotPresent, so the preloaded FODs above are
            # genuinely what runs rather than a registry pull at bring-up.
            image.override = "quay.io/cilium/cilium-ci:${ciliumFixRef}";
            operator.image.override = "quay.io/cilium/operator-generic-ci:${ciliumFixRef}";

            # C69: RKE2's fork ships Hubble DISABLED. Hubble is the entire reason
            # this CNI was chosen, so this is not optional -- Cilium alone buys
            # no observability at all until this lands. relay aggregates the
            # per-node Hubble servers into one `hubble observe`; without it
            # Hubble is a per-node socket.
            #
            # relay is spelled out as an attrset rather than `relay.enabled` plus
            # a separate `relay.image` line: this is a plain Nix attrset inside
            # builtins.toJSON, not a module merge, so two `relay.*` paths would be
            # a duplicate-attribute eval error rather than merging.
            hubble = {
              enabled = true;
              relay = {
                enabled = true;
                image.override = "quay.io/cilium/hubble-relay-ci:${ciliumFixRef}";
              };
              ui.enabled = true;
              metrics.enabled = [ "dns" "drop" "tcp" "flow" "port-distribution" "icmp" "http" ];
            };

            # C68: the init container nsenters PID 1's mount namespace to write
            # /etc/sysctl.d/99-zzz-override_cilium.conf on the host and restart
            # systemd-sysctl. The same keys are declared in boot.kernel.sysctl
            # above, which is the configuration that owns host mutations.
            sysctlfix.enabled = false;

            # Deliberately NOT set, each for a reason:
            #   kubeProxyReplacement -- upstream's `false` stands and RKE2 keeps
            #     its own kube-proxy. KPR is what would attach BPF programs at
            #     the cgroup2 root, ABOVE every process on yoga including the
            #     rootless-podman Radicle forge, and Hubble needs none of it
            #     (C68).
            #   encryption -- the tailnet already WireGuards this traffic. A
            #     second layer would spend 60 more bytes of the same 1280 budget,
            #     taking the pod route MTU to 1170 for confidentiality that
            #     already exists (C19).
            #   cluster/service CIDRs -- RKE2's 10.42/16 and 10.43/16 already
            #     avoid 100.64.0.0/10, the range Tailscale allocates node
            #     addresses from (C25). Setting them would be a knob with no
            #     purpose and a second thing to keep right.
          };
        };
      };
    })
  ]);
}
