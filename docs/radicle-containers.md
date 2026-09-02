# Containerised radicle: roles as machines

Status: **partly built.** Milestones 1 and 2 are committed, and 1 is deployed on
yoga. This document describes what exists; the sections that describe work still
to come say so. It supersedes an earlier version of this file that proposed an
`systemd-nspawn` substrate -- the *shape* it described was right, and only the
substrate changed.

| | Milestone | State | Reverted by |
|---|---|---|---|
| 1 | podman as the default backend | **done, live on yoga** | one enum flip + rebuild |
| 2 | `mkSystem { platform = "oci" }` and the role systems | **done, not deployed** | nothing to revert |
| 3 | one builder role on yoga | **wired, gated shut** | remove the container |
| 4 | move CI to it | to do | re-enable host CI |
| 5 | a second seed, beside the live one | to do | remove the container |
| 6 | retire the host seed | to do | re-enable it -- storage preserved |

Every milestone is additive and independently revertible.

## Why

`my.infra.radicle` runs the node, httpd, explorer, CI broker and mirror directly
on the host. That works, and it is what yoga runs today. One problem pushes hard
enough to build for:

**The seed's key is reachable from CI.** The broker bind-mounts the node's
decrypted private key into the adapter's namespace -- upstream's design, so the
broker can sign job results as the node. `radicle-native-ci` then runs
repository-supplied shell in that namespace. On a seed, that is the key the whole
fleet dials, and `trustedNids` is the only thing between a malicious recipe and
it.

Moving CI into a role with its own disposable identity dissolves that. A builder
key is uninteresting to steal: rotate it in seconds and the fleet is unaffected.

The second motivation -- *placement is welded to hostnames* -- is real but
weaker, and it is worth recording that it is not what justifies the work. It is
answered anyway, because a role is placed by where its container runs.

## A role is a machine

The unit is not a process, it is a **system**: mynixos with one domain switched
on, running its own systemd, its own nginx if it serves something, its own
`tailscaled`. `my.infra.radicle` runs inside it **unchanged**.

That is not a stylistic preference. The domain is systemd all the way down, and
every one of those features is load-bearing:

| Feature | What it does | What a process-shaped image costs |
|---|---|---|
| `StateDirectory` / `LogsDirectory` | directories created after mounts, every start | a race with impermanence -- a bug this repo already hit and fixed (`ci.nix:161-171`) |
| `systemd.paths` (mirror) | inotify on each repo's `sigrefs` | no equivalent; needs a supervisor or a poll loop |
| `BindsTo` (broker → node) | broker dies with its node — upstream's unit, verified live with `systemctl show radicle-ci-broker -p BindsTo` | faked with coupled containers |
| a shell | -- | assertions about the image cannot run, so negative checks pass vacuously |
| the role's own nginx | a builder serves its own `/ci/` reports from `report_dir` (`ci.nix`), and whatever fronts CI proxies to it | reports cross a container boundary to the host |

An earlier draft took "minimal image" literally -- one process, `FROM scratch`,
no init -- and paid every row of that table. Machine-shaped roles make those
problems disappear rather than solving them.

**One systemd feature does not survive the move, and the table used to claim it
did: `LoadCredential`.** systemd builds `$CREDENTIALS_DIRECTORY` by mounting,
so it needs `CAP_SYS_ADMIN` and is unavailable to a rootless role -- the same
constraint that moves sops decryption out to the host (see *Secrets and
identity*). The key is read from a stable path instead. Everything else in the
table works inside a role exactly as it does on a host.

**A role is still not yoga.** It declares no users, so there is no `logger`, no
home-manager, no workstation closure. That property comes from the config, not
from any packaging trick, and `mkSystem` enforces it (below).

## The emitter is `mkSystem`

`lib/mkSystem.nix` dispatches on `platform`, and `"oci"` is a third branch:

```nix
mkSystem {
  platform = "oci";              # emits system.build.image
  system   = "x86_64-linux";     # required here, rejected on linux/darwin
  hostname = "radicle-x64-builder";
  my = {
    infra.radicle     = { enable = true; ci.enable = true; ci.trustedNids = [ … ]; };
    network.tailscale = { enable = true; tags = [ "tag:radicle-builder" ]; };
  };
}
```

| `platform` | emits |
|---|---|
| `"linux"` | `system.build.toplevel` |
| `"darwin"` | `darwinSystem` |
| `"oci"` | `system.build.image` |
| `"vm"` | `system.build.vm` -- one branch away; `vogix-test-vm` does it by hand today |

The enum is flat although it now carries two axes: `linux`/`darwin` are operating
systems, `oci` is an output *format*. A container is implicitly Linux, so it
stays unambiguous in practice, and one word in a host file reads better than a
second argument. `system` is required on this branch and rejected on the others,
because a container has no hardware profile to take an architecture from.

*One definition, many shapes* was claimed by the previous version of this
document and then contradicted by hard-coding a substrate. Putting the axis on
`mkSystem` is what makes it true: a role that outgrows a container moves to bare
metal by changing one argument, and its NID -- which lives in the key, not the
address -- survives untouched.

**The branch rejects what a role cannot have**, each with a reason in the
message: `my.filesystem` (the image *is* the filesystem), `my.storage.impermanence`
(a container's root is already discarded; state is a bind mount the host
declares), `hardware`, `users`, and `my.users` entries carrying a **`fullName`**.
The last one is the subtle one: `lib/active-users.nix` filters on exactly
`fullName`, so such an entry reaches the same account and home-manager modules
the `users` argument does, and would pull a workstation closure into the image.
An entry *without* one is fine -- it carries settings and creates no account.

`roles/radicle/{default,builder,seed,identity}.nix` holds the roles. A role is a
**function** a consumer instantiates with its own keys. The flake's `packages.*`
build a *reference* fleet whose identities have no surviving private halves,
tagged `reference` rather than `latest` so an image built for nobody cannot be
mistaken for a deployment.

### What `platforms/oci.nix` has to undo

It imports `platforms/linux.nix` **wholesale**. That is deliberate and not
wasteful: `mkIf false` still requires an option to be *declared*, so a role that
never boots a bootloader must still carry lanzaboote's and impermanence's
declarations, or any module mentioning them fails to evaluate.

The container shape itself comes from nixpkgs' own
`profiles/docker-container.nix`: `boot.isContainer = true` (no kernel, no initrd,
no bootloader, no `systemd-udev-trigger`), `/init` → `$toplevel/init`, and a
`register-nix-paths` service that loads the nix DB from `/nix-path-registration`
-- which is what makes nix usable inside a builder.

What remains is the set of things `linux.nix` turns on for a laptop and a
container has no business running: **openrgb** (a root daemon with a TCP listener
and SMBus access, pure attack surface in the one role that runs
repository-supplied shell), **audio**, **sshd**, **systemd-oomd**, the flake
registry and channel, and `/run/wrappers` as a *mount* -- the unit is masked and
replaced with a tmpfiles rule, because emptying `security.wrappers` instead would
delete wrappers that things genuinely use.

## Runtime: podman

**Structural reason:** podman is daemonless, so systemd supervises the container
directly. Under docker the container is a child of `dockerd` rather than of the
unit, so systemd cannot genuinely supervise it and a `dockerd` restart takes
everything down at once. For a forge that must come up at boot and stay up, that
decides it.

**Separation:** `logger` keeps a container CLI for interactive work; the forge
must be unreachable from that account. Rootless podman separates per-user *by
construction* -- separate storage, separate subuid ranges, and no daemon means
**no shared control surface**, so `logger` cannot `ps`, `exec` or `stop` a forge
container. Docker cannot offer this: one daemon, one storage tree, one
root-equivalent group per machine.

**The group is gone, not renamed.** `my.dev.docker` enabled rootful *and*
rootless docker and added every dev user to `docker` -- a root-equivalent
membership, since the socket will start a privileged container with `/`
bind-mounted. It is now `my.dev.containers` with a `backend` enum defaulting to
podman, and no group is created on either branch. `DOCKER_HOST` points at the
rootless socket so `docker`-shaped tooling keeps working. Darwin defaults to
docker, where Colima is what runs.

The forge runs under a **dedicated identity**, never `logger` and never root --
`virtualisation.oci-containers` supports this through `containers.<n>.podman.user`.

> The forge runtime must not depend on `my.dev.containers`. One is whether
> `logger` gets a CLI; the other is a system service that runs whether or not
> anyone has logged in. A host with `my.dev.enable = false` must still run a
> builder. This is why the builder states its own persistence entries rather than
> inheriting `/var/lib/containers` from `my/dev/development`.

### Rootless systemd as PID 1: it works, with two failure classes

This was the open question the design could not answer on paper, and it is
answered: **systemd comes up as PID 1 in a rootless container.** Rootless podman
grants a bounding set of CHOWN, DAC_OVERRIDE, FOWNER, FSETID, KILL, SETGID,
SETUID, SETPCAP, NET_BIND_SERVICE, SYS_CHROOT and SETFCAP -- notably **no
`CAP_SYS_ADMIN`**. Two classes of unit fail as a result, and it is worth knowing
which, because the symptoms are not alike:

1. **Units whose mechanism is `mount(2)`.** They fail visibly.
2. **Units that drop to a `User=` *and* install a seccomp filter.** They die at
   step `USER`, which reads as a permissions problem and is not one. `nscd` is
   the example here: the fix is `RestrictSUIDSGID = mkForce false`, not
   disabling the service.

### The failure that reports success

`nixpkgs`' `firewall.service` carries `ConditionCapability=CAP_NET_ADMIN`, and
**systemd *skips* a unit whose condition is unmet rather than failing it**. A
role without that capability therefore comes up reporting `running`, with zero
failed units, and an empty ruleset. Nothing anywhere says the packet filter did
not load.

`platforms/oci.nix` adds a `firewall-enforced.service` that asserts the filter
actually loaded, so the silence becomes a failure. The container is given
`--cap-add=NET_ADMIN` for this reason as much as for `tailscaled`.

This is the general shape to watch for in this work: **checks that pass because
they cannot observe what they claim to test.** Others found the same way: a grep
of `/etc/passwd` in an image whose `/etc` does not exist until `/init` runs, and
`podman exec … sh -c` in an image with no shell.

## Secrets and identity

**The image is identity-free; the container is identified.** One image serves
every builder, and rotating a key is replacing a file with no rebuild. A role
with no identity does not come up as nobody -- `radicle-node` exits
`243/CREDENTIALS` and stays down.

Identity arrives as a read-only bind mount at `identityDir`, holding one file
the role reads: **`node-key`, the private key already decrypted**. The node's
**public** key is not there -- it is public data, it is what a peer pins in
`<nid>@host:port`, and it belongs in the role's arguments beside the `connect`
list it has to agree with.

**The key arrives decrypted, and that is not the design an earlier draft
described.** It said the role mounted an `age.key` and a `secrets.yaml` and let
sops-nix decrypt inside the container. That cannot work: `sops-install-secrets`
mounts a ramfs at the secrets directory -- a tmpfs under `sops.useTmpfs`, but
still `mount(2)` -- and that needs `CAP_SYS_ADMIN`. A role runs
repository-supplied shell, so withholding `SYS_ADMIN` is the entire reason it is
a separate role with a disposable key. Both requirements cannot be met inside
the container, so **decryption moves out**, to a host that has the capability,
and the plaintext is bind-mounted in. `my/infra/radicle` asserts that
`my.secrets` and a role identity are mutually exclusive, because enabling the
former is what puts `sops-install-secrets` back in the activation path.

The failure it produced was legible from neither end: sops reported
`failed to mount filesystem for secrets: cannot mount: operation not permitted`,
which reads as a sops problem, from an activation script, inside a container
whose logs are a nested boot.

What that costs, stated plainly: the key exists decrypted at a stable path for
as long as the container runs, rather than only inside one unit's credentials
directory. It is still encrypted at rest, and it still never enters the store.

`node-key` is mode **0444**, deliberately. `radicle-node` reads its keystore
*after* dropping to `User=radicle` inside the container, and the host's forge
uid maps to container **root** -- so a 0400 file owned by it is unreadable to
the one process that needs it, failing as
`Unlocking node keystore.. Permission denied`. The directory above is `0711`:
traversable but not listable, so a 0700 directory would block the node at the
*path* even when the file itself is readable. Those two failures are
indistinguishable -- both are `Permission denied` on the same `open()`.

**Nothing may come from a flake input.** A `path` input is copied into
`/nix/store`, which is world-readable and permanent, and interpolating one copies
the whole *directory* the named file sits in -- publishing whatever else is
beside it, named nowhere in the configuration. That is not hypothetical: it is
how yoga's live seed private key came to sit in the store at mode `0444`, in two
copies, alongside a zero-byte `.enc` file. `my.secrets.allowSecretsInStore`
(default false) now refuses that shape at evaluation, asserting on both
`defaultSopsFile` and every `sops.secrets.<name>.sopsFile`.

## Hardening, and where it lives

A machine-shaped container cannot use `--cap-drop=ALL`: systemd needs
capabilities a single process does not.

An earlier draft of this document claimed the unit-level hardening applied
again inside the container, giving "two boundaries now, not one". **That was
wrong, and it was wrong in the direction that flatters the design.**
`services.radicle` runs the node under `confinement.mode = "full-apivfs"` with
`ProtectSystem=strict`, `PrivateTmp`, `ProtectHome`, `ProtectProc` and
`ProcSubset` -- and systemd implements every one of those with `mount(2)`.
A rootless container has no `CAP_SYS_ADMIN`, so each of them fails at step
`NAMESPACE`. `my/infra/radicle/default.nix` therefore turns them off under
`boot.isContainer`, for every unit rather than only the one that failed first:
the constraint is a property of the machine, not of a unit.

The honest accounting splits in two, and only one half is a loss:

- **Delivery.** `BindReadOnlyPaths` was how upstream put `config.json` and
  `radicle.pub` where the node reads them. Those files are in the image already;
  tmpfiles symlinks do the same job with no capability at all. Nothing given up.
- **Hardening.** `ProtectSystem`, `PrivateTmp`, `ProtectHome`, `ProtectProc`,
  `ProcSubset` have no substitute without mount namespacing. **Genuinely lost.**

What remains is the container boundary: rootless, a user namespace, no
`SYS_ADMIN`, `no-new-privileges`, a bounded capability set. **One boundary, not
two** -- which is what the code has said since the day it was written.

At the container boundary:

```
--security-opt=no-new-privileges
--systemd=always                         # REQUIRED; see below
--pids-limit / --memory / --memory-swap  # a CI recipe can fork-bomb the host
--cap-add=NET_ADMIN --cap-add=NET_RAW    # tailscaled, and the firewall (above)
no published ports · no socket mount
```

**`--userns=auto` must NOT be used**, though an earlier draft listed it. It
allocates a fresh uid range per container, so the host uid owning the identity
files is not mapped inside and the read-only bind mount reads as an unmapped
owner -- which looks like a file-mode problem and is not one. Plain rootless
podman maps the host account to container root, and that is what makes a
read-only identity mount readable at all. The isolation it was reaching for
belongs at a different seam: **one forge user per role**, which separates
storage, subuid range and control surface by construction. yoga's builder and
its container seed have separate accounts for exactly this reason -- the builder
runs repository-supplied shell, and an escape from it must not reach a seed's
non-disposable key.

**`--systemd=always` is required.** podman sets up `/run`, `/run/lock` and the
cgroup hierarchy as tmpfs only in systemd mode, which it auto-enables *only*
when the command is literally `/sbin/init`, `/usr/sbin/init`,
`/usr/local/sbin/init` or `systemd`. A NixOS toplevel is a store path ending in
`/init`, which matches none of them. Without the flag systemd execs and dies
instantly, printing nothing -- which reads as a broken image and is not one.

`CAP_SYS_ADMIN` is deliberately withheld. A builder runs repository-supplied
shell, which is the whole reason it is a separate role with a disposable key.

**Never mount the podman socket into a container.** Socket access is root
equivalence -- it lets the container ask the engine for a privileged container
with `/` bind-mounted, defeating everything else at once.

### Accepted risk

The builder key remains readable by the CI recipe: the broker hands the decrypted
key to an adapter that runs repository-supplied shell. No delivery mechanism
reaches this -- sops decrypting perfectly still hands plaintext to the process
running the recipe.

The mitigation is what it has always been: it is a **builder's** key, it is
disposable, and rotating it costs seconds. What would *remove* the exposure is a
custom adapter running each build in a nested `--rm` container without the key,
signing outside in the broker. The protocol is small and pinned
(`radicle-ci-broker` 0.31.0, `adapterlib/src/lib.rs`). Deliberately **out of
scope**, and it is what to build if a builder key should ever stop being
disposable.

## Size

Measured, not estimated:

| | closure | store paths |
|---|---|---|
| seed role | **1.20 GB** | 547 |
| builder role | **1.10 GB** | 526 |
| shared between them | 1.06 GB | 489 |
| builder's marginal cost beside a seed | **0.04 GB** | 37 |

The overlap is the point: 489 of ~530 paths are common, so `streamLayeredImage`
turns them into shared layers. The first role costs ~1.2 GB and each additional
role costs its marginal paths -- for a second builder, tens of megabytes. That is
what makes "a role is a machine" affordable at fleet scale rather than merely
correct.

**Optimisation is deliberately deferred.** Make it correct, then shrink it --
separate work, with its own gates, not to be attempted while the architecture is
still settling.

### Why not nspawn

nspawn runs a NixOS system with no adaptation at all, which is a real advantage.
One thing outweighs it: `nixos-containers.nix:195` passes `--bind-ro=/nix/store:/nix/store` on the
`systemd-nspawn` exec line **unconditionally**, mounting the host store into every
container, so a builder running
repository-supplied shell can read yoga's entire closure. For the threat that
motivates this work, a private store is the better answer.

## Storage

A builder has two stores: the image's own `/nix/store`, baked in and immutable;
and wherever the repo's toolchain is realised at CI time. Only the second needs a
volume, at a **separate prefix**.

**Never mount a volume at `/nix`.** It does not add storage, it covers up the
image's own store -- including its init. Podman seeds an empty named volume from
the image on first use, so it appears to work, then never refreshes, leaving the
container running yesterday's store after the next rebuild.

That matters more than "rare": `virtualisation.oci-containers` runs `podman rm -f`
in its pre-start, so the container is destroyed on **every image change** -- and
on `nixos-unstable` the image moves whenever `nix flake update` moves the closure.

State uses bind mounts to paths the host persists, **per role**
(`/var/lib/radicle-roles/<name>/…` -- not `/var/lib/radicle`, which belongs to
the host seed). Unpersisted, a reboot silently loses the node identity, the
tailnet identity and the CI history together.

There is deliberately **no `my.containers` option**. A host writes
`virtualisation.oci-containers` directly, with `imageStream` pointing at the
role's `system.build.image` -- no registry, no tarball in the store. An
abstraction over that is not obviously worth its weight until there is more than
one host running roles.

## Networking

Each role is its own tailnet node, running `tailscaled` inside the machine via
`my.network.tailscale`. The auth key arrives as a **file** (`authKeyFile`), which
the module already supports and already asserts must be paired with tags.

Ports belong to the feature that needs them, not to a general switch: sshd's
reachability on the tailnet is opened by `my/network/openssh`, gated on
`services.openssh.enable`, so a role that switches sshd off advertises nothing.

**The ACL is load-bearing, not incidental.** Filesystem isolation is solid;
network reach is entirely tailnet policy. A builder on the tailnet can otherwise
reach yoga's sshd, the explorer, and anything else served there. Tag the builders
and permit outbound to the seeds and package fetching only, with no inbound --
they dial out, so they need no inbound reachability at all.

## The seed: add one, then retire the other

The seed is **not migrated**. Radicle's replication model makes seeds plural --
each has its own NID -- so a second seed is a normal fleet member, not a cutover.

1. Stand a container seed up **alongside** the running host seed.
2. Let it replicate. Verify under real load.
3. Retire the host seed.

**No destructive step exists.** Rollback at every point is "do nothing" -- the
original keeps running, and even at step 3 its storage is left in place.

Three consequences, all following from the NID living in the key:

- **The container seed gets a new key and therefore a new NID.** It must: two
  nodes on one key would both sign the same sigrefs, and Noise XK pins the
  responder key, so a client dialing that NID could land on either.
- **Every workstation gains a second `connect` entry** -- `<nid>@host:port`, both
  coexisting. This is exactly what P2P redundancy means here: an entry, not a
  VIP. The old one is deleted at step 3.
- **The two seeds `connect` to each other**, and the new one needs
  `defaultSeedingPolicy = "allow"` to pull the repositories across.

Leaving both running is a legitimate end state, not a half-finished migration.

**Steps 1 and 2 are done on yoga** (2026-09-02). `radicle-yoga-seed` runs as a
container role beside the original, with its own tailnet node and its own NID,
and the original is untouched. Replication is not inferred from unit state --
the original seed's journal records the new one fetching from it:

```
Peer z6Mks9Ty… fetched rad:z2WxYCuLx8F8r2bPLPNjjboGM7qPU from us successfully
Peer z6Mks9Ty… fetched rad:z4KpNmJDpSD4xYHcsASaWa9y3AKTd from us successfully
Peer z6Mks9Ty… fetched rad:zfDtFXYCZjVrrJ2gbFUPZVAK1XzC from us successfully
```

Three repositories, not the two named in `seedRepositories` -- the third
followed from `defaultSeedingPolicy = "allow"`. Step 3 is deliberately not
taken.

Two things that verification taught, both about how to *check* rather than what
to build:

- **The public API cannot prove replication here.** These repositories are
  private, so `radicle-httpd` 404s them and `/api/v1/repos` reports zero on
  *both* seeds whether replication worked or not. The seed's journal is the
  honest source, and it needs no privileges; a storage diff needs root, since
  both stores are `0700`.
- **Session state must be sampled over time.** Immediately after a workstation
  switch, the *original* seed cycles `Connected → connection reset` while it
  closes the stale pre-restart session as conflicting. It settles by itself. A
  single sample reads that transient as a dead seed -- or, taken a moment later,
  as a healthy one.

**The mirror is the one role that cannot overlap** -- two mirrors force-push the
same refs. That is free right now: `mirror.enable = false`, GATE C still shut.
Whenever it is switched on, it goes on exactly one seed.

## What is singular and what is plural

| Role | Multiple? | Why |
|---|---|---|
| seed | **yes** | radicle's replication model; each has its own NID |
| httpd / explorer | yes | stateless reads over the seeds' storage |
| CI builder | **yes** | the point -- more lanes across repos |
| **mirror** | **no** | two mirrors force-push the same refs |

**The P2P port cannot be load balanced.** Noise XK requires the initiator to know
the responder key in advance -- `crates/radicle-node/src/wire.rs` declares
`responder: OneWayPattern::Known` -- which is why addresses are
`<nid>@<host>:<port>`. Two nodes with different NIDs behind one address fail the
handshake whenever the balancer picks the wrong one. The HTTP surface balances
normally.

## Settled by building it

- **A builder carries its own toolchain.** `devenv` is added by the builder
  role, not lent by the host: `nix` is already unconditional on the adapter
  PATH, and a host that had to supply the rest would make the role depend on
  where it happens to run -- the exact coupling this design removes. It is
  written as a module rather than passed in as a derivation, so it is evaluated
  by *that* system and gets *that* system's `pkgs`; a package handed in from the
  host embeds the host's package set into a different machine, which works only
  while the two share a nixpkgs and an architecture. Builds succeed on this
  shape.
- **CI reports are read off disk, not out of job COBs.** The builder is the only
  machine its reports exist on, so it serves them itself and whatever fronts CI
  proxies to it. Reading its filesystem from outside would mean matching subuid
  mappings across a userns boundary by hand.
- **Rootless systemd as PID 1 works**, given `--systemd=always` and
  `NET_ADMIN`/`NET_RAW`. The two failure modes look nothing alike and neither
  names its cause: without the flag, systemd dies instantly printing nothing;
  without the capability, `firewall.service` is *skipped* by its
  `ConditionCapability` and the role comes up `running` with an empty ruleset.

## Open questions

- Whether httpd and the explorer become their own roles or stay inside the seed
  machine. Inside is still simpler, but the reason to defer -- "costs nothing
  until a second seed exists" -- has expired: a second seed exists, so there are
  now two explorers, each baked with its own `seedHostname`.
- Whether a `search` role (Meilisearch + `radicle-search`) runs its own replica
  node or shares a seed's storage read-only. Deferred until search is wanted.
- Image size. Deferred deliberately -- correctness first.
- Nothing asserts that a `/run/wrappers` entry actually confers privilege. If
  `/run` is ever mounted `nosuid`, setuid wrappers degrade silently.
