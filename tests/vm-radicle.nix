# Booting two-VM test for the Radicle forge (my.infra.radicle).
#
# The eval tests (module-eval radicle-*) prove the generated CONFIG; this
# proves the RUNTIME claims eval cannot see: the node comes up healthy on a
# network with no internet (the isolated test LAN is the private-network
# property by construction -- there is no iris/rosa to fall back to), a
# workstation profile pushes a repo and the seed's allow-policy picks it up,
# the CI broker fires a native recipe on the fetch and logs its output, and
# the httpd web view answers.
#
# The `seed` node runs the module's seed shape. The `dev` node deliberately
# runs NO system node: it drives the per-user flow (own profile, own key,
# outbound-only daemon dialing the seed) the way a human workstation would --
# the fixture identities under tests/fixtures/radicle are committed on
# purpose, test-only keys that never touch a real network.
#
# What is NOT tested here: the GitHub mirror runtime (its unit embeds the
# github.com URL and the test net has no internet; the storage->canonical
# ref mapping it depends on was verified against a live profile and is
# eval-asserted), sops delivery (fixture key via mkForce'd privateKey), and
# tailscale itself (the test LAN stands in for the tailnet, so the test
# opens the firewall on the LAN interface explicitly).
#
# Heavy (boots 2 VMs, needs /dev/kvm) => `tests` output, not `checks`:
#   nix build .#tests.<sys>.vm-radicle -L
{ self, inputs, system, nixpkgs, ... }:

let
  pkgs = import nixpkgs {
    inherit system;
    config.allowUnfree = true;
  };

  seedNid = "z6MksBiZz5A2o7vh5WA2uiPsTN4a76PDEBnPwuQc1RjbQZt5";
  devNid = "z6MkoUJYanEQB48njQZCa9ujovQjmEFeFRx2K7tQvKJpjbEn";
  seedPub = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIL0soL62TfVfX7JMl4wN+EfZ2gvKFWCFuO+QhdI4ecEK";

  # The dev node's per-user profile config: the exact private-net shape the
  # per-user app module renders (my/users/apps/dev/radicle/linux.nix).
  devConfig = pkgs.writeText "dev-radicle-config.json" (builtins.toJSON {
    preferredSeeds = [ ];
    node = {
      alias = "vm-dev";
      listen = [ ];
      peers.type = "static";
      connect = [ "${seedNid}@seed:8776" ];
      externalAddresses = [ ];
      network = "main";
      seedingPolicy.default = "block";
    };
  });
in
pkgs.testers.runNixOSTest {
  name = "mynixos-vm-radicle";

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
    seed = { lib, ... }: {
      imports = [
        self.nixosModules.default
        inputs.home-manager.nixosModules.home-manager
        inputs.sops-nix.nixosModules.sops
      ];

      boot.loader.grub.enable = false;
      system.stateVersion = "24.11";
      networking.hostName = lib.mkForce "seed";
      virtualisation = {
        memorySize = 2048;
        cores = 2;
      };

      home-manager = {
        useUserPackages = true;
        backupFileExtension = "backup";
        extraSpecialArgs = { inherit inputs; };
        sharedModules = [{ home.stateVersion = "24.11"; }];
      };

      my = {
        system.enable = true;
        system.hostname = "seed";
        theming.enable = false;
        secrets.enable = true;
        network.tailscale.enable = true;

        infra.radicle = {
          enable = true;
          publicKey = seedPub;
          node = {
            externalAddresses = [ "seed:8776" ];
            defaultSeedingPolicy = "allow";
          };
          httpd.enable = true;
          ci = {
            enable = true;
            trustedNids = [ devNid ];
          };
        };
      };

      # Test-only overrides: the fixture key replaces the sops secret (the
      # path is a store path, which still takes the LoadCredential branch),
      # and the LAN interface stands in for tailscale0.
      services.radicle.privateKey = lib.mkForce "${./fixtures/radicle/seed.key}";
      sops.secrets = lib.mkForce { };
      networking.firewall.allowedTCPPorts = [ 8776 8780 ];
    };

    dev = _: {
      # No mynixos here at all: this machine drives the per-user flow with
      # nothing but the CLI, a profile, and an outbound-only daemon.
      boot.loader.grub.enable = false;
      system.stateVersion = "24.11";
      virtualisation.memorySize = 1024;
      environment.systemPackages = [
        pkgs.radicle-node
        pkgs.gitMinimal
        pkgs.iproute2 # `ss`: the connection assertions below
      ];
    };
  };

  testScript = ''
    import json

    start_all()

    with subtest("seed node comes up healthy with zero public egress available"):
        seed.wait_for_unit("radicle-node.service")
        seed.wait_for_open_port(8776)
        cfgpath = seed.succeed(
            "systemctl show -P BindReadOnlyPaths radicle-node.service"
            " | tr ' ' '\n' | grep -o '^/nix/store/[^:]*config\\.json' | head -1"
        ).strip()
        cfg = json.loads(seed.succeed(f"cat {cfgpath}"))
        assert cfg["preferredSeeds"] == [], f"public seeds leaked into config: {cfg['preferredSeeds']}"
        assert cfg["node"]["peers"]["type"] == "static", "node not pinned to static peers"
        assert cfg["node"]["seedingPolicy"] == {"default": "allow", "scope": "all"}, cfg["node"]["seedingPolicy"]

    with subtest("httpd answers on the tailnet-only port"):
        seed.wait_for_unit("radicle-httpd.service")
        seed.wait_until_succeeds("curl -sf http://127.0.0.1:8780/api/v1 | grep -q version", timeout=60)

    with subtest("CI broker is up and bound to the node"):
        seed.wait_for_unit("radicle-ci-broker.service")

    with subtest("dev workstation: profile + outbound-only user node"):
        dev.succeed("mkdir -p /root/.radicle/keys")
        dev.succeed("cp ${./fixtures/radicle/dev.key} /root/.radicle/keys/radicle")
        dev.succeed("cp ${./fixtures/radicle/dev.pub} /root/.radicle/keys/radicle.pub")
        dev.succeed("chmod 600 /root/.radicle/keys/radicle")
        dev.succeed("cp ${devConfig} /root/.radicle/config.json")
        dev.succeed(
            "systemd-run --unit=dev-radicle-node"
            " -p Environment=RAD_HOME=/root/.radicle"
            " -p Environment=HOME=/root"
            " ${pkgs.radicle-node}/bin/radicle-node --config /root/.radicle/config.json"
        )
        # `rad node status` EXITS 0 while the node is stopped (it just prints
        # "Node is stopped"), so it is useless as a readiness gate -- assert
        # the control socket instead, which only exists once the daemon runs.
        dev.wait_until_succeeds("test -S /root/.radicle/node/control.sock", timeout=60)

    with subtest("dev connects to exactly the seed, and to nothing else"):
        # `rad node status` lists every configured peer whether or not it is
        # connected, so grepping the NID alone would pass with the seed
        # powered off -- it would only echo back what devConfig set. Assert
        # an ESTABLISHED TCP session to the seed's node port instead, and
        # that it is the only radicle-node peer connection on the box.
        dev.wait_until_succeeds(
            "ss -tnp state established '( dport = :8776 )' | grep -q radicle-node", timeout=120
        )
        peers = dev.succeed(
            "ss -tnH state established '( dport = :8776 or sport = :8776 )'"
            " | awk '{print $4}' | sort -u | wc -l"
        ).strip()
        assert peers == "1", f"expected exactly one radicle peer session, got {peers}"

    with subtest("push a repo with a CI recipe; the seed's allow-policy picks it up"):
        dev.succeed("mkdir -p /root/demo/.radicle")
        # The recipe writes a marker file (upstream's own broker test does the
        # same): recipe stdout lands in native-ci's run records, not anywhere
        # greppable from outside, and the adapter's CWD is the broker's
        # RuntimeDirectory.
        dev.succeed(
            "echo 'shell: echo -n RADICLE-CI-RAN > /run/radicle-ci-broker/result'"
            " > /root/demo/.radicle/native.yaml"
        )
        dev.succeed("echo hello > /root/demo/README.md")
        dev.succeed(
            "cd /root/demo && git init -q -b main . && git add ."
            " && git -c user.email=vm@test -c user.name=vm commit -qm init"
        )
        dev.succeed(
            "cd /root/demo && RAD_HOME=/root/.radicle RAD_PASSPHRASE="
            " rad init --public --name demo --description vm --default-branch main --no-confirm"
        )
        rid = dev.succeed("cd /root/demo && RAD_HOME=/root/.radicle rad inspect").strip()
        assert rid.startswith("rad:"), f"unexpected rad inspect output: {rid}"
        storage = "/var/lib/radicle/storage/" + rid.removeprefix("rad:")
        seed.wait_until_succeeds(f"test -d {storage}", timeout=120)

    with subtest("canonical refs materialize on the seed"):
        seed.wait_until_succeeds(
            f"${pkgs.gitMinimal}/bin/git --git-dir={storage} rev-parse refs/heads/main >/dev/null",
            timeout=120,
        )

    with subtest("CI fired on the fetch and the recipe ran"):
        try:
            got = seed.wait_until_succeeds(
                "cat /run/radicle-ci-broker/result", timeout=180
            )
            assert got == "RADICLE-CI-RAN", f"unexpected recipe output: {got!r}"
        except Exception:
            print("=== broker journal ===")
            print(seed.execute("journalctl -u radicle-ci-broker --no-pager | tail -60")[1])
            print("=== broker config ===")
            print(seed.execute("cat $(systemctl show -P ExecStart radicle-ci-broker.service | grep -o '/nix/store/[^ ]*ci-broker.json')")[1])
            print("=== ci state/logs ===")
            print(seed.execute("ls -laR /var/lib/radicle-ci /var/log/radicle-ci 2>&1 | head -60")[1])
            raise
  '';
}
