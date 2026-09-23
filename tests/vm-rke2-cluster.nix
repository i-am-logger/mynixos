# Booting two-VM test for the RKE2 + Cilium cluster (my.infra.rke2).
#
# THIS TEST WAS WRITTEN BEFORE THE MODULE IT TESTS, deliberately. nixpkgs' own
# `nixos/tests/rancher/` suite exercises **canal only** (default.nix:56-68 loads
# the canal airgap set and nothing else), so Cilium-on-NixOS is CI-tested by
# nobody -- which makes this file load-bearing rather than diligent
# (docs/k8s-fleet-constraints.md, C72). It is expected to FAIL until the module
# lands. Nothing in it may be weakened to make it pass early.
#
# What it borrows from where:
#   * tests/vm-radicle.nix       -- the house shape: N VMs on the driver's
#                                   isolated LAN, mynixos loaded the way a host
#                                   loads it, test-only overrides marked as such.
#   * nixos/tests/rancher/multi-node.nix
#                                -- the already-CI-tested mechanics: a local
#                                   pause image, a DaemonSet to prove cross-node
#                                   pod networking, and pinning the CNI through
#                                   `rke2.manifests.<name>.content` carrying a
#                                   HelmChartConfig, which multi-node.nix:110-114
#                                   records is the ONLY way to configure a
#                                   packaged RKE2 chart. Here that manifest is
#                                   the module's job, not the harness's.
#
# THE TAILNET IS THE TEST LAN. The fleet's nodes meet over Tailscale, never on a
# shared L2, and every node-to-node port is scoped to `tailscale0` (C21). There
# is no tailnet in a VM, so eth1 stands in for it and the harness opens the same
# ports on eth1 that the module opens on tailscale0 -- exactly the substitution
# tests/vm-radicle.nix:20-22 makes. Two things follow, and both are asserted
# rather than assumed:
#   * the nodes address each other on 100.64.0.0/24, the range Tailscale
#     allocates from, so a module that waits for a CGNAT address before starting
#     rke2 (C65) finds one; and
#   * no rule that reaches a cluster port may be interface-less. The harness's
#     own rules carry `-i eth1`, so the assertion still catches a module that
#     regressed to fleet-wide `networking.firewall.allowedTCPPorts`.
#
# THE FIREWALL IS MODELLED ON PURPOSE, and this test is what settled the argument
# about it. `checkReversePath` began unset here, at NixOS's strict default, exactly
# as it was unset throughout mynixos and both host files -- so the
# `nixos-fw-rpfilter` mangle chain with its DROP default was live while
# decapsulated VXLAN traffic crossed it. Whether that traffic survived
# `-m rpfilter --validmark` was the most consequential and least verified finding
# in the design: reasoned from the rule, never observed on a real packet (C73).
#
# It does not survive. This test observed 55 drops across four of Cilium's `lxc*`
# pod veths, every one with a pod-CIDR source, including pod DNS to the upstream
# resolvers -- so the module now sets `checkReversePath = "loose"` (C109), which is
# an evidenced relaxation rather than a precautionary one. `loose` still rejects
# traffic with no return path by any route, so the chain remains worth asserting:
# `logReversePathDrops` stays on and a drop of CLUSTER traffic is still a failure.
# A test that switched the firewall off entirely would have proved nothing here,
# and would have shipped a cluster whose pods could not resolve DNS.
#
# Heavy (boots 2 VMs, loads the RKE2 airgap image set, needs /dev/kvm) =>
# `tests` output, not `checks`:
#   nix build .#tests.<sys>.vm-rke2-cluster -L
{ self, inputs, system, nixpkgs, lib, ... }:

let
  pkgs = import nixpkgs {
    inherit system;
    config.allowUnfree = true;
  };

  # The tailnet stand-in. 100.64.0.0/10 is the range Tailscale allocates node
  # addresses from -- the same range C25 forbids the pod and service CIDRs from
  # overlapping, which RKE2's defaults (10.42/16, 10.43/16) already satisfy.
  serverAddr4 = "100.64.0.1";
  agentAddr4 = "100.64.0.2";
  supervisorPort = 9345; # NOT 6443: an agent bootstraps through the supervisor.

  # THE number. The pod ROUTE MTU this fleet's configuration must produce, and
  # the one thing this whole file exists to pin (C18, C58, C66). It is not the
  # knob: the Cilium `MTU` value is 1280 -- tailscale0's fixed TUN MTU -- and
  # getRouteMTU subtracts the 50-byte IPv4 VXLAN overhead from whatever is
  # configured. Setting the knob to 1230 would yield 1180.
  podRouteMTU = 1230;
  ciliumDeviceMTU = 1280;

  # Test-only join token. A store path, which is exactly what C29 forbids on a
  # real host -- there it comes from sops-nix at a runtime path, mode 0400, and
  # `tokenFile` rather than `token` so the value never lands in a unit. Here
  # there is no sops, and the token is a published constant on purpose.
  tokenFile = pkgs.writeText "rke2-vm-test-token" "vm-test-join-token-not-a-secret";

  # The pause image doubles as the workload image, the way nixos/tests/rancher
  # does it: the VMs have no internet, so everything is `imagePullPolicy: Never`
  # against a locally-imported tarball.
  imageEnv = pkgs.buildEnv {
    name = "rke2-vm-test-env";
    paths = with pkgs; [
      tini
      bashInteractive
      coreutils
      socat
      iproute2 # `ip route`: the MTU assertion reads the pod's route table
      dnsutils # `nslookup`: the in-cluster DNS assertion
    ];
  };

  pauseImage = pkgs.dockerTools.buildImage {
    name = "test.local/pause";
    tag = "local";
    copyToRoot = imageEnv;
    config = {
      Entrypoint = [ "/bin/tini" "--" "/bin/sleep" "inf" ];
      Env = [ "PATH=/bin" ];
    };
  };

  # A DaemonSet (one pod per node, which is what makes "cross-node" true rather
  # than hoped for) plus a Service in front of it, so DNS has something real to
  # resolve.
  workload = pkgs.writeText "netcheck.yml" ''
    apiVersion: apps/v1
    kind: DaemonSet
    metadata:
      name: netcheck
      namespace: default
      labels:
        name: netcheck
    spec:
      selector:
        matchLabels:
          name: netcheck
      template:
        metadata:
          labels:
            name: netcheck
        spec:
          containers:
          - name: netcheck
            image: test.local/pause:local
            imagePullPolicy: Never
            resources:
              limits:
                memory: 96Mi
            command: ["socat", "TCP4-LISTEN:8000,fork", "EXEC:echo netcheck"]
    ---
    apiVersion: v1
    kind: Service
    metadata:
      name: netcheck
      namespace: default
    spec:
      selector:
        name: netcheck
      ports:
      - port: 8000
        targetPort: 8000
  '';

  # The sysctl keys `services.rke2.enable = true` adds, COMPUTED from the
  # upstream module rather than transcribed from it.
  #
  # rancher/rke2.nix:144 writes them inside `mkIf cfg.enable` and OUTSIDE the
  # `cisHardening` guard that starts at :151, so every host that enables RKE2
  # gets them whether or not it asked for CIS hardening (C76). The value
  # assertions in the test script catch the four keys known today; this list is
  # what catches a nixpkgs bump adding a FIFTH one -- which is the actual bug
  # class ("an upstream module reaches outside its own domain"), and which would
  # otherwise surface as a surprise reboot on a workstation whose root is a
  # tmpfs rather than as a red test (C77).
  #
  # A bump that changed an EXISTING key's value cannot hide here either: both
  # definitions are plain values, so the module system would report a conflict
  # rather than merge them.
  rke2SysctlKeys =
    let
      sysctlOf = extra:
        (lib.nixosSystem {
          modules = [
            {
              nixpkgs.hostPlatform = system;
              boot.loader.grub.enable = false;
              fileSystems."/" = { device = "/dev/vda"; fsType = "ext4"; };
              system.stateVersion = "24.11";
            }
            extra
          ];
        }).config.boot.kernel.sysctl;
    in
    lib.sort (a: b: a < b) (lib.subtractLists
      (builtins.attrNames (sysctlOf { }))
      (builtins.attrNames (sysctlOf { services.rke2.enable = true; })));

  # The four keys the module must mkForce back to the fleet's values, per key.
  panicSysctls = [ "kernel.panic" "kernel.panic_on_oops" "vm.overcommit_memory" "vm.panic_on_oom" ];

  # Cilium's device names are constants (cilium/pkg/defaults/node.go:21, :24,
  # :36, :72). `lxc+` is iptables' wildcard, NOT a shell glob -- `lxc*` would
  # match nothing and fail silently, which is the shape C22 exists to catch.
  ciliumInterfaces = [ "cilium_host" "cilium_net" "cilium_vxlan" "lxc+" ];

  # Every node-to-node port, from docs/rke2-cluster.md's table. 9345 is the one
  # people forget: it is the supervisor, the registration endpoint an agent
  # dials before it has any kubeconfig, and an agent that reaches 6443 but not
  # 9345 never joins with a failure that reads as an authentication problem.
  clusterTCPPorts = [ 6443 9345 10250 4240 4244 ];
  clusterUDPPorts = [ 8472 ];

  # A cluster node. `role` and the addresses are all that differ.
  mkNode = { role, addr4, nodeName }: { config, ... }: {
    imports = [
      self.nixosModules.default
      inputs.home-manager.nixosModules.home-manager
      inputs.sops-nix.nixosModules.sops
    ];

    boot.loader.grub.enable = false;
    system.stateVersion = "24.11";

    virtualisation = {
      cores = 4;
      memorySize = if role == "server" then 6144 else 4096;
      diskSize = 20480;
    };

    home-manager = {
      useUserPackages = true;
      backupFileExtension = "backup";
      extraSpecialArgs = { inherit inputs; };
      sharedModules = [{ home.stateVersion = "24.11"; }];
    };

    my = {
      system.enable = true;
      system.hostname = nodeName;
      theming.enable = false;
      # C88's last assertion: the join token comes from sops, so the domain
      # refuses to build without it even though this test overrides the
      # delivery below.
      secrets.enable = true;
      # The module orders rke2 after tailscaled (C65). Enabling it here keeps
      # that ordering satisfiable; the daemon never reaches a control plane and
      # is not asked to -- eth1 carries the tailnet's address range instead.
      network.tailscale.enable = true;

      infra.rke2 = {
        enable = true;
        inherit role nodeName;
        # Identity is a name, the bootstrap address is a literal IP (C82):
        # tailscaled's resolver is not up when rke2 starts, so an agent
        # bootstrapping against a MagicDNS name cannot resolve it.
        nodeIP = addr4;
        tokenFile = "${tokenFile}";
      } // lib.optionalAttrs (role == "server") {
        # Every name a peer might use, decided BEFORE first start. The serving
        # certificate is generated once and persisted, and --tls-san-security
        # defaults to true, so a name missing at this moment cannot be added by
        # rebuilding -- it takes imperative surgery against persisted state
        # (C78). This is the one thing in the whole design that a rebuild
        # cannot fix.
        tlsSan = [ "server" serverAddr4 ];
      } // lib.optionalAttrs (role == "agent") {
        serverAddr = "https://${serverAddr4}:${toString supervisorPort}";
      };
    };

    # ---- test-only overrides ------------------------------------------------

    # There is no sops here; the token arrives as a store path above. On a real
    # host this attrset is where `rke2-token` lives at mode 0400 (C30).
    sops.secrets = lib.mkForce { };

    networking = {
      hostName = lib.mkForce nodeName;

      # The tailnet stand-in address, alongside the driver's own 192.168.1.x.
      interfaces.eth1.ipv4.addresses = [
        { address = addr4; prefixLength = 24; }
      ];

      # The module opens these on tailscale0, which does not exist in a VM. The
      # harness opens the same set on the interface that IS the tailnet here.
      # Note what is deliberately NOT set: `trustedInterfaces` (the module must
      # supply Cilium's, per C22) and `checkReversePath` (NixOS's strict default
      # stands, per C73).
      firewall = {
        interfaces.eth1 = {
          allowedTCPPorts = clusterTCPPorts;
          allowedUDPPorts = clusterUDPPorts;
        };
        logReversePathDrops = true;
      };
    };

    # kubectl is NOT the module's job (C5, C6): client tooling arrives through
    # the per-user apps tree so that "this machine talks to the cluster" and
    # "this machine is in it" stay separable. The harness installs its own.
    environment.systemPackages = with pkgs; [
      kubectl
      jq
      hubble # the Hubble CLI, for the assertion that Relay actually reports
    ];

    services = {
      # The previous boot's journal is where the clean-shutdown assertion reads,
      # and a volatile journal would take it with the reboot.
      journald.extraConfig = "Storage=persistent";

      rke2 = {
        # No internet in here, so the workload image is imported from a tarball
        # and the sandbox image is overridden to the same one. The module
        # supplies the RKE2 airgap set itself, keyed on hostPlatform (C40) -- if
        # it names an architecture literally, or omits the cilium set, nothing
        # starts.
        images = [ pauseImage ];
        extraFlags = [ "--pause-image test.local/pause:local" ];
        # Trimmed for VM resources. rke2-coredns stays: the DNS assertion needs
        # it. rke2-ingress-nginx is the module's to disable (C83) -- it is a
        # hostNetwork DaemonSet that would take :443 from the live forge.
        #
        # SERVER ONLY, and the first run of this test is why. `--disable` is a
        # server flag; the rke2 agent subcommand does not define it, and nixpkgs
        # appends it to ExecStart for BOTH roles (rancher/default.nix:940) while
        # only WARNING that an agent should not set it. So an agent that carries
        # this list dies immediately with
        #   level=fatal msg="Error: flag provided but not defined: -disable"
        # and the cluster never reaches Ready. Nothing catches it at eval time --
        # the module now asserts it, which is the durable half of this fix.
        disable = lib.optionals (role == "server") [
          "rke2-metrics-server"
          "rke2-snapshot-controller"
          "rke2-snapshot-controller-crd"
          "rke2-snapshot-validation-webhook"
        ];
      };
    };

    # IMPERMANENCE, MODELLED -- and this unit is what gives the reboot assertion
    # its teeth.
    #
    # yoga's root is a 16 GB tmpfs and anything not named in
    # `my.system.persistence.features.systemDirectories` is gone at every boot.
    # A VM has an ordinary persistent disk, so a plain reboot would preserve
    # EVERYTHING and the reboot subtest would pass against a module that
    # declares no persistence at all -- proving nothing. This unit reproduces
    # the wipe from the module's OWN declaration: state the module did not claim
    # is discarded before rke2 starts, exactly as impermanence would discard it.
    #
    # It must run before systemd-tmpfiles, because tmpfiles is what recreates
    # the `L+` symlinks into /nix/store that rke2 reads its manifests and images
    # through (rancher/default.nix:849, :856) -- and those symlinks are
    # precisely what must NOT be persisted (C80).
    systemd.services.wipe-unpersisted-cluster-state =
      let
        keep = lib.escapeShellArgs (map (d: d.directory or d)
          config.my.system.persistence.features.systemDirectories);
      in
      {
        description = "Discard cluster state the cluster module did not declare persisted";
        wantedBy = [ "sysinit.target" ];
        after = [ "local-fs.target" ];
        before = [ "systemd-tmpfiles-setup.service" "sysinit.target" "shutdown.target" ];
        conflicts = [ "shutdown.target" ];
        unitConfig.DefaultDependencies = false;
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
        };
        path = with pkgs; [ coreutils findutils ];
        script = ''
          set -eu
          keep_list=(${keep})

          # true when $1 is a declared path, or sits under one
          is_kept() {
            local p="$1" k
            for k in "''${keep_list[@]}"; do
              case "$p" in "$k"|"$k"/*) return 0 ;; esac
            done
            return 1
          }

          # true when some declared path sits under $1, so $1 must be descended
          # into rather than removed
          leads_to_kept() {
            local p="$1" k
            for k in "''${keep_list[@]}"; do
              case "$k" in "$p"/*) return 0 ;; esac
            done
            return 1
          }

          scrub() {
            local dir="$1" entry
            [ -d "$dir" ] || return 0
            while IFS= read -r -d "" entry; do
              if is_kept "$entry"; then
                continue
              elif leads_to_kept "$entry"; then
                scrub "$entry"
              else
                rm -rf -- "$entry"
              fi
            done < <(find "$dir" -mindepth 1 -maxdepth 1 -print0)
          }

          for tree in /etc/rancher /var/lib/rancher /var/lib/kubelet /var/lib/cni; do
            scrub "$tree"
          done
        '';
      };
  };
in
pkgs.testers.runNixOSTest {
  name = "mynixos-vm-rke2-cluster";

  node.specialArgs = {
    inherit inputs self pkgs;
    inherit (inputs)
      disko
      impermanence
      vogix
      hypr-vogix
      lanzaboote
      sops-nix
      ;
  };

  nodes = {
    server = mkNode { role = "server"; addr4 = serverAddr4; nodeName = "server"; };
    agent = mkNode { role = "agent"; addr4 = agentAddr4; nodeName = "agent"; };
  };

  testScript = ''
    import json
    import re
    import time

    # KUBECONFIG is set for THIS shell only. Setting it fleet-wide is what turns
    # the admin file's mode into every login session's default credential, which
    # is the second half of C43 and is asserted against below (C45).
    KC = "KUBECONFIG=/etc/rancher/rke2/rke2.yaml"

    def kubectl(args):
        return server.succeed(f"{KC} kubectl {args}")

    def kubectl_json(args):
        return json.loads(kubectl(f"{args} -o json"))

    start_all()

    def dump_cluster_state(why):
        """Print why the cluster is not up, on the way to failing.

        Without this the first wait times out and the run says only "timed out",
        with 900 seconds of silence behind it -- the bring-up failures live in
        CONTAINER logs (the helm-install job, cilium-agent), which never reach the
        journal the harness prints. Each iteration of this test costs ~20 minutes,
        so a run that fails without saying why costs another whole run to diagnose.
        """
        print(f"\n=== CLUSTER DID NOT COME UP: {why} ===")
        for label, cmd in [
            ("nodes", f"{KC} kubectl get nodes -o wide"),
            ("node conditions", f"{KC} kubectl get nodes -o json | jq -r '.items[].status.conditions[] | \"\\(.type)=\\(.status) \\(.reason) \\(.message)\"'"),
            ("all pods", f"{KC} kubectl get pods -A -o wide"),
            ("non-running pods", f"{KC} kubectl get pods -A --field-selector=status.phase!=Running -o json | jq -r '.items[] | \"\\(.metadata.namespace)/\\(.metadata.name) \\(.status.phase) \\(.status.conditions // [] | map(.message) | join(\"; \"))\"'"),
            ("recent events", f"{KC} kubectl get events -A --sort-by=.lastTimestamp | tail -40"),
            ("helm jobs", f"{KC} kubectl -n kube-system get jobs"),
            ("helm-install-rke2-cilium logs", f"{KC} kubectl -n kube-system logs job/helm-install-rke2-cilium --tail=80"),
            ("cilium pods", f"{KC} kubectl -n kube-system logs -l k8s-app=cilium --tail=60 --all-containers"),
            ("containerd images", "k3s crictl images 2>/dev/null | head -30"),
        ]:
            out = server.execute(cmd)[1]
            print(f"\n--- {label} ---\n{out}")
        print("\n--- rke2-server journal (tail) ---")
        print(server.execute("journalctl -u rke2-server --no-pager | tail -60")[1])
        print("\n--- rke2-agent journal (tail) ---")
        print(agent.execute("journalctl -u rke2-agent --no-pager | tail -60")[1])

    with subtest("both nodes reach Ready"):
        server.wait_for_unit("rke2-server.service", timeout=900)
        agent.wait_for_unit("rke2-agent.service", timeout=900)
        try:
            server.wait_until_succeeds(f"{KC} kubectl get node agent", timeout=900)
            for node in ("server", "agent"):
                kubectl(f"wait --for=condition=Ready node/{node} --timeout=900s")
        except Exception as e:
            dump_cluster_state(str(e))
            raise

    with subtest("the four panic sysctls hold the fleet's values, not RKE2's"):
        # `services.rke2.enable = true` writes these machine-wide, outside its
        # own cisHardening guard. On yoga -- a daily-driver desktop running
        # amdgpu whose root is a 16 GB tmpfs -- kernel.panic_on_oops = 1 turns a
        # GPU oops into a panic and kernel.panic = 10 reboots ten seconds later,
        # and that reboot DISCARDS THE ROOT FILESYSTEM. The blast radius is the
        # workstation, not the cluster (C76). The module mkForces each key back,
        # per key.
        added = ${builtins.toJSON rke2SysctlKeys}
        expected = ${builtins.toJSON panicSysctls}
        assert added == expected, (
            "the upstream rke2 module's sysctl set changed: "
            f"expected {expected}, nixpkgs now adds {added}. "
            "Every new key needs its own mkForce -- see C76/C77."
        )
        # THE KUBELET WINS THIS, ALWAYS -- and the assertion encodes that rather
        # than the wish it started as (C111/C112).
        #
        # Kubernetes' setKernelTunables (pkg/kubelet/cm/container_manager_linux.go)
        # enforces a fixed table at kubelet startup, writing /proc/sys directly
        # from inside a container -- after systemd-sysctl, unjournalled, and
        # invisible to every sysctl.d file. Verified by extracting the kubelet
        # from rancher/rke2-runtime and reading its strings: "Updating kernel
        # flag", "Invalid kernel flag", "protect-kernel-defaults".
        #
        # There is no setting that avoids it: --protect-kernel-defaults=false
        # (the default) makes the kubelet OVERWRITE, and =true makes it REFUSE TO
        # START unless the values already match. So a Kubernetes node cannot run
        # with kernel.panic_on_oops = 0, and the module's mkForce governs only the
        # boot-time value and a host with rke2 stopped.
        #
        # The fleet accepts this (C112). What is still worth asserting is that the
        # values are the KUBELET's and nothing else has drifted in -- and, above,
        # that nixpkgs has not added a FIFTH key, which was always the real bug
        # class this subtest exists for (C77).
        kubelet_enforced = {
            "kernel.panic": "10",
            "kernel.panic_on_oops": "1",
            "vm.panic_on_oom": "0",
            "vm.overcommit_memory": "1",
        }
        for machine in (server, agent):
            bad = {}
            for key in expected:
                got = machine.succeed(f"sysctl -n {key}").strip()
                want = kubelet_enforced.get(key)
                if want is None:
                    bad[key] = f"{got} (key not in the kubelet's table -- who set it?)"
                elif got != want:
                    bad[key] = f"{got}, expected the kubelet's {want}"
            if bad:
                # The Nix-level value is provably 0 (grep the built system's
                # /etc/sysctl.d/60-nixos.conf), and a minimal VM running nixpkgs'
                # rke2 plus the same mkForce yields 0 at runtime. So a non-zero
                # here means something wrote /proc/sys AFTER systemd-sysctl, and
                # the question is only WHO. Deduction already cost more than this
                # dump does: rke2 itself only READS these (and only under
                # --profile=cis, which is off), and k3s's runtime sysctl setter
                # touches networking keys alone.
                print(f"\n=== SYSCTL DRIFT on {machine.name}: {bad} ===")
                print(machine.succeed("grep -rH . /etc/sysctl.d/ 2>&1 | grep -iE 'panic|overcommit' || true"))
                print("--- files present, in application order ---")
                print(machine.succeed("ls -1 /etc/sysctl.d/ /run/sysctl.d/ /usr/lib/sysctl.d/ 2>&1 || true"))
                print("--- systemd-sysctl ---")
                print(machine.succeed("systemctl show systemd-sysctl -p Result,ExecMainStatus,ExecMainExitTimestamp || true"))
                print(machine.succeed("journalctl -u systemd-sysctl --no-pager | tail -30 || true"))
                print("--- did anything restart it after boot? ---")
                print(machine.succeed("journalctl --no-pager | grep -iE 'sysctl' | tail -30 || true"))
                print("--- cilium's init containers (sysctlfix should be OFF) ---")
                print(machine.execute(f"{KC} kubectl -n kube-system get ds cilium -o jsonpath='{{.spec.template.spec.initContainers[*].name}}'")[1])
            assert not bad, (
                f"{bad}. These should hold the KUBELET's enforced values (C111): it "
                "rewrites them at startup from setKernelTunables and no flag prevents "
                "that. A mismatch means either the kubelet's table changed upstream or "
                "something else is now writing /proc/sys -- both worth knowing. The "
                "module's mkForce governs only the boot-time value. See the dump above."
            )

    with subtest("the admin kubeconfig is not world-readable"):
        # The file embeds the cluster-admin client certificate AND its private
        # key. The module this replaces chmod 644'd it from a oneshot, driven by
        # an option that defaulted to true (C43).
        mode = server.succeed("stat -c %a /etc/rancher/rke2/rke2.yaml").strip()
        assert int(mode, 8) & 0o007 == 0, f"admin kubeconfig is mode {mode}: it has a world bit"
        # ... and nothing makes cluster-admin the default identity of a login
        # shell. environment.variables lands in /etc/set-environment (C45).
        server.fail("grep -q KUBECONFIG /etc/set-environment")

    with subtest("Cilium: transparent encryption OFF, kube-proxy-replacement OFF"):
        cm = kubectl_json("-n kube-system get cm cilium-config")["data"]
        # The tailnet already WireGuards this traffic. A second layer would be
        # double-encrypt and would spend 60 more bytes of the same 1280 budget,
        # taking the pod route MTU to 1170 for confidentiality that already
        # exists (C19).
        for key in ("enable-ipsec", "enable-wireguard"):
            assert cm.get(key, "false") == "false", f"{key} is {cm.get(key)}: encryption is not off"
        # KPR is what would attach BPF programs at the cgroup2 root, ABOVE every
        # process on yoga including the rootless-podman Radicle forge. Hubble
        # needs none of it, and RKE2's fork never sets it (C68).
        kpr = cm.get("kube-proxy-replacement", "false")
        assert kpr in ("false", "disabled"), f"kube-proxy-replacement is {kpr}"
        # The knob, not the assertion: 1280 is the device MTU that yields 1230.
        assert cm.get("mtu") == "${toString ciliumDeviceMTU}", (
            f"cilium-config mtu is {cm.get('mtu')}, not ${toString ciliumDeviceMTU} -- "
            "an unset knob means Cilium recomputes per host, and the endpoint-MTU "
            "updater is disabled by RKE2's portmap chaining, so nothing propagates it"
        )
        # Positive corroboration that KPR really is off: RKE2 keeps deploying
        # its own kube-proxy, one static pod per node.
        proxies = [p for p in kubectl_json("-n kube-system get pods")["items"]
                   if p["metadata"]["name"].startswith("kube-proxy")]
        assert len(proxies) == 2, f"expected a kube-proxy on each node, found {len(proxies)}"

    with subtest("cross-node pod-to-pod traffic works"):
        kubectl("apply -f ${workload}")
        server.wait_until_succeeds(f"{KC} kubectl rollout status daemonset/netcheck --timeout=600s", timeout=900)
        pods = kubectl_json("get pods -l name=netcheck")["items"]
        placed = {p["spec"]["nodeName"]: (p["metadata"]["name"], p["status"]["podIP"]) for p in pods}
        assert set(placed) == {"server", "agent"}, f"the DaemonSet did not land on both nodes: {placed}"
        server_pod, server_pod_ip = placed["server"]
        agent_pod, agent_pod_ip = placed["agent"]

        # Both directions, and only across the node boundary -- a same-node pair
        # would pass without the overlay carrying anything.
        got = kubectl(f"exec {server_pod} -- socat TCP:{agent_pod_ip}:8000 -").strip()
        assert got == "netcheck", f"server-pod -> agent-pod returned {got!r}"
        got = kubectl(f"exec {agent_pod} -- socat TCP:{server_pod_ip}:8000 -").strip()
        assert got == "netcheck", f"agent-pod -> server-pod returned {got!r}"

    with subtest("the pod route MTU is ${toString podRouteMTU}, read as a number"):
        # DO NOT "simplify" this into a large-payload test. Cilium sets neither
        # DF on cilium_vxlan nor BPF_F_DONT_FRAGMENT, so an oversized outer
        # packet is IP-fragmented by the local kernel, carried, and reassembled
        # at the peer -- A PAYLOAD TEST PASSES ON A MISCONFIGURED CLUSTER
        # (C67, refuting C20). What a wrong value actually costs is throughput
        # collapse, reassembly pressure and loss amplification, none of which a
        # payload assertion can see, and UDP and QUIC get no PLPMTUD rescue.
        #
        # This is the single most important assertion in the file and the reason
        # it was written before the implementation.
        for pod in (server_pod, agent_pod):
            route = kubectl(f"exec {pod} -- ip route show default")
            m = re.search(r"\bmtu (\d+)\b", route)
            assert m, f"{pod}'s default route carries no MTU at all: {route!r}"
            got = int(m.group(1))
            assert got == ${toString podRouteMTU}, (
                f"{pod}'s pod route MTU is {got}, not ${toString podRouteMTU}. "
                "The Cilium knob is 1280 and getRouteMTU subtracts the 50-byte "
                "IPv4 VXLAN overhead from it; a knob of 1230 would show 1180 here (C66)."
            )
        # The other half of the same arithmetic: the DEVICE MTU the knob sets.
        for machine in (server, agent):
            link = machine.succeed("ip -o link show cilium_vxlan")
            m = re.search(r"\bmtu (\d+)\b", link)
            assert m and int(m.group(1)) == ${toString ciliumDeviceMTU}, (
                f"cilium_vxlan device MTU is {link!r}, expected ${toString ciliumDeviceMTU}"
            )

    with subtest("in-cluster DNS resolves a Service"):
        # WAIT FOR COREDNS FIRST. Node Ready is not CoreDNS Ready: the kubelet
        # reports Ready as soon as the CNI initialises, while rke2-coredns is a
        # helm-installed Deployment that schedules afterwards. Without this the
        # subtest raced it and failed with
        #   ;; communications error to 10.43.0.10#53: connection refused
        # -- the ClusterIP existing with no endpoints behind it, which reads like
        # a network fault and is not one. Every other subtest waits on its own
        # precondition; this one inherited an assumption instead.
        # Waited on by BEHAVIOUR rather than by resource name: the chart's
        # objects are named rke2-coredns-rke2-coredns and its Service may also be
        # aliased, so a name-based wait is a guess that fails as a timeout and
        # tells you nothing. "DNS answers" is the actual precondition, and it is
        # also the only one that covers pods Ready AND kube-proxy having
        # programmed the Service -- refused-with-no-endpoints, which is what this
        # raced, satisfies neither.
        server.wait_until_succeeds(
            f"{KC} kubectl exec {server_pod} -- "
            "nslookup kubernetes.default.svc.cluster.local",
            timeout=600,
        )

        cluster_ip = kubectl_json("get svc netcheck")["spec"]["clusterIP"]
        out = kubectl(f"exec {server_pod} -- nslookup netcheck.default.svc.cluster.local")
        assert cluster_ip in out, f"netcheck.default.svc.cluster.local did not resolve to {cluster_ip}: {out!r}"
        # Resolution alone would pass against a Service that routes nowhere.
        got = kubectl(f"exec {agent_pod} -- socat TCP:{cluster_ip}:8000 -").strip()
        assert got == "netcheck", f"the Service resolved but did not route: {got!r}"

    with subtest("Hubble is actually working: Relay up AND flows observable"):
        # Hubble is the entire reason this CNI was chosen, and RKE2's fork ships
        # it DISABLED (hubble.enabled: false, C69). A green cluster with a Relay
        # that is up and reporting nothing is a FAILED build, not a partial one
        # -- so "Relay is Available" is half the assertion and a real flow is
        # the other half.
        server.wait_until_succeeds(
            f"{KC} kubectl -n kube-system rollout status deployment/hubble-relay --timeout=600s",
            timeout=900,
        )
        # hubble-relay is a ClusterIP service reached over the pod network, so
        # the CLI goes through a port-forward -- the same shape a workstation
        # would use.
        server.succeed(
            f"systemd-run --unit=hubble-portforward --collect --setenv={KC}"
            " kubectl -n kube-system port-forward svc/hubble-relay 4245:80"
        )
        server.wait_until_succeeds("hubble --server localhost:4245 status", timeout=180)
        # Tap the stream BEFORE generating traffic, so this cannot pass on a
        # stale ring buffer or fail on an evicted one.
        server.succeed(
            # ABSOLUTE PATH, deliberately. systemd-run resolves only its FIRST
            # argument against the caller's PATH -- everything inside `bash -c`
            # runs with the unit's own minimal PATH, which has no
            # /run/current-system/sw/bin. A bare `hubble` here died instantly with
            # status=127 "command not found" while the port-forward above worked,
            # because there kubectl IS the first argument.
            "systemd-run --unit=hubble-tap --collect ${pkgs.bashInteractive}/bin/bash -c"
            " '${pkgs.hubble}/bin/hubble --server localhost:4245 observe --follow --output json > /tmp/hubble-flows.json'"
        )
        # Assert the tap is ALIVE, and without `|| true`. That suffix made this
        # wait pass unconditionally, so a tap that had already exited 127 sailed
        # through here and surfaced 180 seconds later as an unexplained timeout on
        # the flow grep -- the failure was reported three steps from its cause.
        server.wait_until_succeeds("systemctl is-active hubble-tap.service", timeout=30)
        try:
            # TRAFFIC IS REGENERATED ON EVERY RETRY, and that is the whole point.
            # `hubble observe --follow` streams from the moment its gRPC session
            # to Relay is established, not from the buffer. Sending a fixed burst
            # up front and then waiting raced that setup: the five connections
            # completed inside ~0.5s while the tap was still connecting, so the
            # flows were never streamed, and the test then waited 180s for an
            # event that had already happened and would not repeat. Hubble was
            # working the whole time -- 2/2 nodes connected, thousands of flows
            # buffered. Putting the traffic INSIDE the retry makes a missed window
            # self-healing rather than fatal.
            server.wait_until_succeeds(
                f"{KC} kubectl exec {server_pod} -- socat TCP:{agent_pod_ip}:8000 - >/dev/null; "
                f"grep -q {agent_pod_ip} /tmp/hubble-flows.json",
                timeout=180,
            )
        except Exception:
            # Hubble is the ENTIRE reason this CNI was chosen, so a silent tap is
            # the most important thing in this file to diagnose rather than retry.
            # `hubble status` passes through wait_until_succeeds, which swallows
            # its output -- and its peer count is the first thing worth seeing:
            # Relay aggregates per-node Hubble servers, so 0 connected peers means
            # the servers are not enabled or not reachable, not that flows are
            # missing.
            print("\n=== HUBBLE: relay is up but no flow matched ===")
            print("--- hubble status (peer count is the tell) ---")
            print(server.execute("${pkgs.hubble}/bin/hubble --server localhost:4245 status")[1])
            print("--- flow file: size, then first lines ---")
            print(server.execute("wc -c /tmp/hubble-flows.json; head -c 2000 /tmp/hubble-flows.json")[1])
            print("--- the tap unit ---")
            print(server.execute("systemctl status hubble-tap.service --no-pager -l | head -20")[1])
            print("--- what the agent thinks Hubble is doing ---")
            print(server.execute(f"{KC} kubectl -n kube-system exec ds/cilium -c cilium-agent -- cilium-dbg status --verbose 2>&1 | grep -iA6 hubble")[1])
            print("--- hubble-related keys in cilium-config ---")
            print(server.execute(f"{KC} kubectl -n kube-system get cm cilium-config -o json | ${pkgs.jq}/bin/jq -r '.data|to_entries[]|select(.key|test(\"hubble\"))|\"\\(.key)=\\(.value)\"'")[1])
            print("--- relay logs ---")
            print(server.execute(f"{KC} kubectl -n kube-system logs deploy/hubble-relay --tail=40")[1])
            raise

        # ... and the flow that arrived really is the cross-node pair, not some
        # unrelated chatter that happened to mention the address.
        found = False
        for line in server.succeed("cat /tmp/hubble-flows.json").splitlines():
            try:
                event = json.loads(line)
            except ValueError:
                continue
            flow = event.get("flow", event)
            ip = flow.get("IP", {})
            if {ip.get("source"), ip.get("destination")} == {server_pod_ip, agent_pod_ip}:
                found = True
                break
        assert found, (
            "hubble-relay is up but reported no flow between the two pods -- "
            "Hubble is the reason this CNI was chosen (C69/C71)"
        )

    with subtest("cluster ports are interface-scoped and strict rpfilter dropped nothing"):
        # C21/C46: the module this replaces wrote
        # `networking.firewall.allowedTCPPorts = [ cfg.apiPort ]` -- every
        # interface -- which on a laptop offers the Kubernetes API to whatever
        # cafe wifi it is attached to. The harness's own rules carry `-i eth1`,
        # so a module that regressed to a fleet-wide rule still fails here.
        for machine in (server, agent):
            for line in machine.succeed("iptables -S nixos-fw").splitlines():
                if re.search(r"--dport (6443|9345|10250|4240|4244)\b", line):
                    assert " -i " in line, f"cluster port opened on every interface: {line}"

        # C22: trustedInterfaces must follow the CNI actually in use. The module
        # this replaces hardcoded flannel's cni0/flannel.1; under Cilium those
        # never appear, the real ones are untrusted, and pod traffic is dropped
        # by the host firewall with nothing in any log naming the cause.
        rules = server.succeed("iptables -S nixos-fw")
        for iface in ${builtins.toJSON ciliumInterfaces}:
            assert re.search(r"-A nixos-fw -i " + re.escape(iface) + r" -j nixos-fw-accept", rules), (
                f"{iface} is not a trusted interface; iptables -S nixos-fw:\n{rules}"
            )

        # C73: strict reverse-path filtering stays on. Assert the chain is
        # genuinely live first -- otherwise "no drops" would prove nothing --
        # and only then that the overlay crossed it intact. This is the finding
        # ranked most consequential and least verified in the whole design: no
        # packet was ever observed being dropped, so this is the observation.
        # Scoped to CLUSTER traffic, and the exclusions are not a convenience: an
        # unfiltered "no drops at all" fails in this harness for reasons that have
        # nothing to do with the cluster. Measured on the first run to get here --
        # 201 drops, of which
        #   199  IN=eth0 SRC=127.0.0.1 DST=10.0.2.15 PROTO=ICMP
        #        QEMU slirp emitting ICMP with a spoofed loopback source.
        #        10.0.2.0/24 is slirp's own range; impossible on real hardware.
        #     2  IN=tailscale0 SRC=100.100.100.100 DST=100.100.100.100
        #        MagicDNS talking to itself.
        # Neither is pod, node or overlay traffic. What survives the filter is
        # what C73 actually asks about. Do NOT widen these exclusions to make a
        # run pass: a drop on cilium_vxlan or a pod CIDR is the finding itself.
        for machine in (server, agent):
            machine.succeed("iptables -t mangle -S nixos-fw-rpfilter | grep -q -- '-m rpfilter'")
            drops = machine.succeed(
                "journalctl -b --no-pager | grep 'rpfilter drop: ' "
                "| grep -v 'SRC=127.0.0.1' "
                "| grep -v 'SRC=100.100.100.100 DST=100.100.100.100' "
                "|| true"
            ).strip()
            assert not drops, (
                "strict reverse-path filtering dropped CLUSTER traffic -- C73's "
                f"open question, answered in the negative:\n{drops}"
            )

        # C64/C74: nixpkgs' rke2 module writes its own NetworkManager
        # unmanaged-devices file, and 'r' sorts after '9', so rke2-canal.conf
        # wins over my/system/core's 99-unmanaged-cni.conf and silently drops
        # the podman*/br-* exclusions that keep NetworkManager off the LIVE
        # Radicle forge. One owner for the key; this is the other one, forced off.
        for machine in (server, agent):
            machine.fail("test -e /etc/NetworkManager/conf.d/rke2-canal.conf")

    with subtest("a rebooted node rejoins as itself, and its shutdown is clean"):
        # THE assertion that distinguishes correct persistence from the broken
        # half-persisted state (C81). Node identity lives in TWO places --
        # /etc/rancher/node/password and the rke2 state root -- and of the three
        # outcomes only two are stable: both persisted rejoins as itself,
        # neither self-heals as a new-but-identical node, and ONE OF THE TWO is
        # broken on every boot, because the server remembers a password the node
        # no longer has. That failure happens at RE-REGISTRATION rather than at
        # boot and reads as a network problem, so nothing else in this suite
        # reaches it.
        #
        # wipe-unpersisted-cluster-state.service is what makes this real: it
        # discards, from the module's own persistence declaration, everything
        # the module did not claim.
        uid_before = kubectl_json("get node agent")["metadata"]["uid"]
        password_before = agent.succeed("sha256sum /etc/rancher/node/password").split()[0]

        started = time.monotonic()
        agent.shutdown()
        elapsed = time.monotonic() - started
        # C87: the rancher unit sets KillMode = process, deliberately leaving
        # containerd and every pod running when the unit stops, and the pod
        # mounts nested beneath the kubelet directory are what block unmounting
        # the persist filesystem. A blocked unmount does not FAIL -- it hangs
        # until systemd's 90 s stop timeout force-kills it -- so the assertion
        # is on the clock. A healthy shutdown here is seconds.
        assert elapsed < 60, (
            f"the agent took {elapsed:.0f}s to power off; a shutdown blocked on "
            "pod mounts hangs until systemd's 90s timeout (C87)"
        )

        agent.start()
        agent.wait_for_unit("rke2-agent.service", timeout=900)
        kubectl("wait --for=condition=Ready node/agent --timeout=600s")

        password_after = agent.succeed("sha256sum /etc/rancher/node/password").split()[0]
        assert password_after == password_before, (
            "the node password did not survive the reboot: /etc/rancher/node is "
            "not in my.system.persistence.features.systemDirectories, which is the "
            "half-persisted state that breaks at every re-registration (C81)"
        )
        agent.fail("journalctl -b --no-pager | grep -q 'Node password rejected'")

        names = sorted(n["metadata"]["name"] for n in kubectl_json("get nodes")["items"])
        assert names == ["agent", "server"], f"the reboot re-registered a new node: {names}"
        assert kubectl_json("get node agent")["metadata"]["uid"] == uid_before, (
            "the agent's node object was replaced rather than rejoined"
        )

        # The previous boot's own account of the shutdown, which the wall clock
        # cannot see: journald is persistent on these nodes for exactly this.
        previous = agent.succeed("journalctl -b -1 --no-pager")
        for symptom in ("Failed unmounting", "Forcibly powering off", "still mounted"):
            assert symptom not in previous, f"unclean shutdown: {symptom!r} in the previous boot's journal"
  '';
}
