# Option tree for the RKE2 + Cilium cluster. An options FRAGMENT loaded through
# mkOptionsModule from platforms/linux.nix, like every other one-sided domain --
# so the platforms file, and nothing else, is what decides that these options
# exist on Linux only (docs/k8s-fleet-constraints.md, C1/C2).
#
# The surface is deliberately small, and what is ABSENT is the design:
#
#   - no `package`. C86: `pkgs.rke2` is a moving alias (`rke2_stable` was
#     `rke2_1_33` in one nixpkgs tree and is `rke2_1_35` in the pinned one), and
#     skyspy-dev is away for months at a time -- it would come back one or two
#     minors ahead of its server, and an agent newer than its server does not
#     join. The version is pinned in ./default.nix, which is the ONE shared place
#     both hosts read. A per-host `package` option is the same bug with extra
#     steps.
#   - no `apiPort`, no `disableTraefik`. The ports are RKE2's own constants and
#     are not negotiable per host; naming a vendor's bundled component in a
#     vendor-neutral namespace is what `my.infra.k3s.disableTraefik` did.
#   - no `kubeconfigReadable`. The option it replaces defaulted to TRUE and drove
#     a `chmod 644` on a file holding the cluster-admin key (C43). The mode is a
#     mode, it is 0600, and the type below refuses a world bit.
#   - no client tooling switch. kubectl/k9s/helm arrive as per-user apps under
#     my/users/apps, on BOTH platforms, so that "this machine talks to the
#     cluster" and "this machine is in it" stay separable (C5, C6).
#   - no architecture. A host states that once, through its hardware profile;
#     asking again would be two sources for one fact (C42).
{ lib, ... }:

{
  # Type-only second declaration of `my.infra`: my/infra/options.nix owns the
  # description and default, and duplicating those would collide. Submodule
  # TYPES merge, so this adds `rke2` to the existing option -- the same shape
  # my/infra/radicle/options.nix uses.
  infra = lib.mkOption {
    type = lib.types.submodule {
      options.rke2 = lib.mkOption {
        description = "RKE2 Kubernetes cluster member, with Cilium as the CNI";
        default = { };
        type = lib.types.submodule ({ config, ... }: {
          options = {
            enable = lib.mkEnableOption "this node's membership of the RKE2 cluster";

            role = lib.mkOption {
              type = lib.types.enum [ "server" "agent" ];
              default = "server";
              description = ''
                Whether this node runs the control plane (`server`) or is a
                worker that joins one (`agent`).

                There is exactly one server on this fleet and no HA: three
                always-on members do not exist to be had, and an agent is not an
                etcd member at all, so a second machine joining as an agent costs
                the control plane nothing when it reboots into Windows (C7, C79).
              '';
            };

            cni = lib.mkOption {
              type = lib.types.nullOr (lib.types.enum [ "cilium" ]);
              default = if config.role == "server" then "cilium" else null;
              defaultText = lib.literalExpression ''if role == "server" then "cilium" else null'';
              description = ''
                The CNI the server deploys, as an RKE2 packaged chart.

                Server-side only: RKE2 installs the CNI from the server's
                manifests, and setting it on an agent is a no-op that reads as
                configuration -- which is what the assertion in ./default.nix
                catches.

                The enum has one value on purpose. This module implements
                Cilium: its HelmChartConfig, its MTU arithmetic and its interface
                names. A second value would be a stub until someone implements
                the three.
              '';
            };

            nodeName = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
              description = ''
                The name this node carries in the cluster. IDENTITY IS A NAME
                (C23, C82) -- an IP is what changes when a machine is rebuilt.

                Left null the kubelet uses the hostname, which on this fleet is
                also what my/network/tailscale pins the tailnet name to.
              '';
            };

            nodeIP = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
              description = ''
                This node's own tailnet address, advertised to the cluster.

                A LITERAL IP, not a MagicDNS name (C82). Without it the kubelet
                picks the interface carrying the default route, which on these
                hosts is a 1500-byte physical NIC no other node can reach (C24).

                ./default.nix also waits for this address to exist before rke2
                starts: unit ordering after `tailscaled` and address availability
                are different readiness conditions (C65).
              '';
            };

            serverAddr = lib.mkOption {
              type = lib.types.str;
              default = "";
              example = "https://100.97.96.49:9345";
              description = ''
                The supervisor an agent bootstraps against.

                PORT 9345, NOT 6443: 9345 is the supervisor, the registration
                endpoint an agent dials before it has any kubeconfig. A node that
                reaches 6443 but not 9345 never joins, and the failure reads as
                an authentication problem.

                A literal tailnet IP for the same reason as `nodeIP`:
                tailscaled's resolver is not up when rke2 starts, so an agent
                bootstrapping against a MagicDNS name cannot resolve it (C82).
              '';
            };

            tlsSan = lib.mkOption {
              type = lib.types.listOf lib.types.str;
              default = [ ];
              example = [ "yoga.tail46cce1.ts.net" "yoga" "100.97.96.49" ];
              description = ''
                Every name a peer might use to reach this server, as
                `--tls-san` flags. There is no nixpkgs option for this (C78).

                THE ONE THING A REBUILD CANNOT FIX. The serving certificate is
                generated once, at first start, and then persisted, and
                `--tls-san-security` defaults to true -- so a name missing at
                that moment cannot be added by changing this list and rebuilding.
                It takes imperative surgery against persisted state. Include the
                MagicDNS name, the short hostname and the tailnet IP; adding one
                later costs exactly what forgetting all of them costs.
              '';
            };

            tokenFile = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
              description = ''
                Path to the cluster join token, if it is delivered by something
                other than this module's sops secret.

                Left null the module declares `sops.secrets.<tokenSecret>` at
                mode 0400 and reads its runtime path. Either way it is a FILE:
                the string-valued `services.rke2.token` renders `--token <value>`
                into the unit, and the unit is a store path -- world-readable,
                permanent, and carried along by `nix copy` (C27, C29).
              '';
            };

            tokenSecret = lib.mkOption {
              type = lib.types.str;
              default = "rke2-token";
              description = ''
                Name of the sops secret holding the join token.

                Let RKE2 generate the token once and then store it (C102): every
                etcd snapshot's bootstrap blob holds every CA private key,
                encrypted under a key derived from this token. A snapshot without
                the token is an unopenable file; the token without a snapshot is
                merely a fresh cluster.
              '';
            };

            kubeconfigMode = lib.mkOption {
              # The trailing digit is the WORLD triad, and the assertion in
              # ./default.nix requires it to be 0. Kept as a string because that
              # is what `--write-kubeconfig-mode` takes and because "0600" and
              # 600 are not the same number.
              type = lib.types.str;
              default = "0600";
              example = "0640";
              description = ''
                Mode for the admin kubeconfig the server writes, through
                `--write-kubeconfig-mode`.

                That file embeds the cluster-admin client certificate AND its
                private key. Mode 644 -- what the module this replaces set from a
                oneshot, driven by an option that defaulted to true -- grants
                full, unauthenticated, unaudited cluster-admin to every local
                account and every process on the host (C43). Any mode with a
                world bit is rejected at eval time (C44).
              '';
            };

            kubeconfigGroup = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
              description = ''
                Group for the admin kubeconfig, through
                `--write-kubeconfig-group`. The second shape C44 allows: `0640`
                root-owned with a dedicated group whose membership is declared.

                Null keeps the file root-only, which is the first shape -- and
                then interactive users get a SCOPED credential rather than this
                one.
              '';
            };

            upstreamNameservers = lib.mkOption {
              type = lib.types.listOf lib.types.str;
              default = [ "1.1.1.1" "9.9.9.9" ];
              description = ''
                Real upstream resolvers for the kubelet's `--resolv-conf`.

                `/etc/resolv.conf` on a tailnet host points at MagicDNS
                (100.100.100.100), which is a valid global-unicast address -- so
                the kubelet's loopback-resolver detection does not fire, every
                pod inherits it, and CoreDNS' upstream forwarder becomes the
                local tailscaled. A tailscaled restart then takes down all
                in-cluster DNS (C84). Cluster DNS must not share a failure domain
                with the daemon whose failure mode is "restart it".

                The default pair is the one my.network.headscale already hands
                the tailnet.
              '';
            };
          };
        });
      };
    };
  };
}
