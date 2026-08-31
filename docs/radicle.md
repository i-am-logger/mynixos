# Radicle: the tailnet-private forge

`my.infra.radicle` runs a [Radicle](https://radicle.dev) (heartwood) forge that
exists only inside the Tailscale tailnet: a seed node with a web view, CI that
builds for x86_64-linux, aarch64-linux and aarch64-darwin, and an event-driven
mirror that keeps chosen repositories -- and their releases -- public on
GitHub. Radicle is the source of truth; GitHub is a projection.

## How the network is private

`network = "test"` is **not** isolation -- it only empties the bootstrap list,
and a "test" node still talks to any main-network node that reaches it. The
real mechanisms, all pinned by the module:

| Layer | Mechanism |
|---|---|
| Reachability | listen on `[::]`, but 8776/8780 are opened on `tailscale0` only (`my.network.tailscale.allowedTCPPorts`); `externalAddresses` empty unless the host layer says otherwise |
| Dialing | `peers = { type = "static" }` -- the node dials `connect` and nothing else |
| Bootstrap | a non-empty `connect` keeps iris/rosa out of the address book entirely (heartwood only inserts them when `connect` AND the address book are empty) |
| Seed hints | `preferredSeeds = []` pinned -- `rad auth` writes the PUBLIC seeds there by default |
| Per-repo | `rad init --private` + `rad id update --allow did:key:<nid>` |

Two honest caveats: private repos are **not encrypted at rest** (every
allow-listed node holds plaintext), and radicle has had private-RID gossip
leaks fixed as recently as 1.10.1 -- the tailnet boundary, not radicle's
privacy layer, is what this design trusts. There is no formal security audit
of heartwood yet.

Every machine gets its **own identity** (NID); one-identity-across-machines is
upstream work-in-progress. A machine that should read a private repo must be
on that repo's allow list.

## Bootstrap runbook

### 1. Identities

Per human+machine (workstations):

```console
$ rad auth --alias <user>@<host>     # answer the passphrase prompt with ENTER
$ rad self --nid                     # record the NID (works with the node stopped)
```

Passphrase-less is the deliberate choice on this fleet: disks are encrypted,
and a passphrase-protected key cannot start a node non-interactively.

For the seed host's machine key (never run `rad auth` against the real
`/var/lib/radicle` -- generate offline and deliver via sops):

```console
$ export RAD_HOME=$(mktemp -d) RAD_PASSPHRASE=
$ rad auth --alias seed-yoga
$ rad self --nid                                  # -> connect entries on every other machine
$ cat $RAD_HOME/keys/radicle.pub                  # -> my.infra.radicle.publicKey (STRIP the comment)
$ sops set …  # private key file content -> secrets.yaml under radicle/node-key
$ rm -rf $RAD_HOME
```

### 2. Seed host

```nix
my.infra.radicle = {
  enable = true;
  publicKey = "ssh-ed25519 AAAA…";                    # no comment!
  node = {
    externalAddresses = [ "yoga.<tailnet>.ts.net:8776" ];
    defaultSeedingPolicy = "allow";                   # seed everything ours
  };
  httpd.enable = true;                                # web view on :8780
};
```

Verify after `rebuild-system`: `systemctl status radicle-node radicle-httpd`,
`ss -tlnp | grep -E '8776|8780'`, and the no-egress proof below.

### 3. Workstations and the Mac

Per user (cross-platform; the daemon half is Linux-only):

```nix
apps.dev.tools.radicle = {
  enable = true;                                      # rad + git-remote-rad
  node = {
    enable = true;                                    # Linux: systemd user service
    connect = [ "<seedNID>@yoga.<tailnet>.ts.net:8776" ];
  };
};
```

The user service stays dormant until `rad auth` has been run once; the next
login pins `~/.radicle/config.json` to the private-net shape
(radicle-config-pin). On the Mac there is no daemon -- `rad node start` when
needed; the CLI works regardless because pushes land in local storage first.

### 4. First repository

```console
$ rad init --private --name <repo>                   # you become the delegate
$ rad id update --allow did:key:<seed NID>           # let the seed hold it
$ rad id update --allow did:key:<other machine NIDs> # every reader
$ git push rad
```

Public-to-the-fleet repos skip the allow dance: `rad init --public` and the
seed's `allow` policy picks them up on announcement. Pin repos the seed must
carry in `seedRepositories` (rendered as an idempotent `rad seed` oneshot).

### 5. No-egress proof

Run once after bringing the seed up, and after upgrades that touch radicle:

```console
$ journalctl -u radicle-node --since=-1h | grep -Ei 'iris|rosa|radicle\.network' && echo LEAK || echo clean
$ ss -tnp | grep radicle-node          # peers must be 100.64.0.0/10 / fd7a:115c:a1e0::/48 only
$ sudo tcpdump -i <wan-if> port 8776   # silent while a sync runs on tailscale0
```

## CI

One broker fleet-wide, on the seed host. Radicle CI has no job matrix and job
results (COBs) do not aggregate across brokers -- but `nix build` already fans
out: x86_64-linux native, aarch64-linux via the binfmt qemu that `my.dev`
hosts always carry, aarch64-darwin via the Mac declared in
`my.dev.remoteBuilders`.

```nix
my.infra.radicle.ci = {
  enable = true;
  trustedNids = [ "<workstation NIDs>" ];   # mandatory; see below
};
```

A repo opts in with `.radicle/native.yaml`; the module puts `nix` and the
`radicle-ci-build` helper on the recipe PATH:

```yaml
shell: |
  radicle-ci-build linux .#packages.x86_64-linux.default .#packages.aarch64-linux.default
  radicle-ci-build darwin --policy best-effort .#packages.aarch64-darwin.default
```

`radicle-ci-build darwin` probes the builder (TCP 22, 5s) first:
`best-effort` prints a loud `### DARWIN BUILD SKIPPED ###` and exits 0 when
the laptop is asleep; `required` fails the run; `off` skips silently. Green
therefore means "linux green, darwin as declared" -- a policy, never a silent
failure. Read results from any machine with `rad job list` (package
`radicle-job`), or on the seed's web view.

**Why `trustedNids` is mandatory (asserted):** the broker executes
repository-supplied shell, and the nixpkgs unit bind-mounts the node's
decrypted key into its reach. Without the `Node` trigger filter, anyone who
can land a patch on a seeded repo runs arbitrary code on the seed with the
node's identity. On this tailnet-private network every writer is us -- that,
and only that, is why the trade is acceptable. Never widen `trustedNids`
beyond fleet machines, and never expose the seed publicly while CI is on.

**CI and the mirror share a host, and therefore a user.** The broker must run
as `radicle` (upstream's design -- it needs the node's storage and key), and
so must the mirror (storage objects are `0600 radicle`). While a mirror run is
in flight its GitHub token sits in `/run/credentials/radicle-mirror-*.service`,
readable by that same uid -- so a CI recipe could read it. On this fleet that
is the same trust boundary as the node key and is accepted knowingly. If you
ever seed a repo you do not fully control, split the roles: `ci.enable` and
`mirror.enable` are independent per-host flags, so the mirror can live on a
host that runs no CI.

## The darwin remote builder

The Mac accepts builds through a locked-down account; radicle-CI-on-macOS
does not exist upstream (broker/adapters are Linux-only, Ambient needs KVM),
so this is the entire macOS story for CI.

```nix
# Mac (host layer):
my.dev.builderHost = {
  enable = true;                       # requires services.openssh.enable
  authorizedKey = "ssh-ed25519 AAAA…"; # public half of nix/remote-builder-key
};

# Linux clients:
my.dev.remoteBuilders = [{
  hostName = "aether5d-dev.<tailnet>.ts.net";
  systems = [ "aarch64-darwin" ];
  publicHostKey = "<base64 -w0 /etc/ssh/ssh_host_ed25519_key.pub>";
}];
```

One-time steps: `ssh-keygen -t ed25519 -N "" -f builder_ed25519`, private half
to sops as `nix/remote-builder-key`, public half into `authorizedKey`; after
the first darwin rebuild, restart the daemon once
(`sudo launchctl kickstart -k system/org.nixos.nix-daemon`). Prove it from a
Linux host: `nix build nixpkgs#legacyPackages.aarch64-darwin.hello -L` -- then
close the lid and rerun to see the fast, loud failure (ConnectTimeout 5).
Also verify the installer's boot-time `nix-installer repair` plist leaves
`/etc/nix/nix.custom.conf` alone and that the installed nix.conf `!include`s
it -- if not, `extra-trusted-users = nixremote` is a one-line manual add.

With no node on the Mac, its radicle READ path is the seed's httpd:
`git clone http://yoga.<tailnet>.ts.net:8780/<alias>.git` (set
`httpd.aliases`); writes route through a Linux machine. The rad CLI is
installed regardless -- local storage inspection works offline, and it is the
ready seam if a launchd node is ever wanted.

The account is non-admin, hidden (uid < 500), and its authorized key carries
`restrict,command="…/nix-daemon --stdio"` -- the key cannot be used for
anything but building. sshd on the Mac is already pf-scoped to tailscale
addresses and pubkey-only.

## GitHub mirror + releases

No Radicle-to-GitHub bridge exists anywhere; this module's mirror is the
bespoke answer, and it runs on the seed because a mirror must announce from a
long-lived node.

```nix
my.infra.radicle.mirror = {
  enable = true;
  sourceNid = "<your main NID>";       # whose signed view is truth
  repos = [{
    rid = "rad:z…";
    githubRepo = "i-am-logger/<repo>"; # must already exist, empty
    releases = {
      enable = true;
      systems = [ "x86_64-linux" "aarch64-linux" "aarch64-darwin" ];
    };
  }];
  notifyCommand = "curl -fsS -d \"mirror failed: $MIRROR_UNIT\" https://…";
};
```

Mechanics worth knowing:

- **Event-driven.** A path unit watches the delegate's `sigrefs` file in
  storage (rewritten on every signed update); pushes reach GitHub seconds
  after the seed fetches them. An hourly timer is the safety net and the
  release-retry loop.
- **Canonical refs only.** Storage refs are per-peer namespaced; the mirror
  fetches `rad://<rid>/<sourceNid>` -- the delegate's view, the only one
  carrying every branch and tag -- into canonical names and pushes those.
  Namespace/COB refs never touch GitHub.
- **Token hygiene.** A fine-grained PAT (Contents: RW on exactly the listed
  repos) sops-delivered as `radicle/github-token`, injected via
  LoadCredential and a git credential helper -- never argv, never a URL.
  (It is readable by CI recipes while a mirror run is in flight -- see the CI
  section.)
- **It refuses to push an empty ref space.** A stale or mistyped `sourceNid`
  names an empty namespace; the fetch would succeed with zero refs and the
  `--prune` push would then delete every branch and tag on GitHub. The unit
  checks for refs first and fails loudly instead.
- **Releases.** A new `v*` tag triggers `gh release create --verify-tag
  --generate-notes`, with artifacts built from the **GitHub ref just pushed**
  (`github:<owner>/<repo>/<tag>#packages.<system>.<attribute>`), so what is
  attached is bit-for-bit what was published. darwin artifacts require the
  Mac awake; a failed attempt notifies and is retried by the timer until it
  lands.
- Test the failure path first: deploy with a bogus token, watch
  `notifyCommand` fire, then install the real one.

## Operations

- `rad-system <cmd>` runs `rad` inside the node's namespaces (nixpkgs ships
  it); `cibtool-system` likewise for the broker.
- State: `/var/lib/radicle` (node + storage), `/var/lib/radicle-ci` +
  `/var/log/radicle-ci` (CI), `/var/lib/radicle-mirror` (mirror workdirs) --
  all persisted through impermanence automatically.
- Key rotation: new `rad auth`, update `publicKey`/sops, then
  `rad id update --allow` the new DID on every private repo and retire the
  old one.
- Tests: `module-eval-radicle-{seed,workstation,config-valid}` and the
  type-validation rejections run in `nix flake check`; the runtime story is
  `nix build .#tests.x86_64-linux.vm-radicle -L` (two VMs, needs /dev/kvm).
