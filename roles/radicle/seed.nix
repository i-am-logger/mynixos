# The Radicle SEED role: node + httpd + explorer, as a machine.
#
# `my.infra.radicle` is reused UNCHANGED -- this file switches one domain on
# and says nothing about how the node, the web view or the explorer are built.
# That is the whole point of a role being a machine: LoadCredential,
# StateDirectory, systemd.paths and the per-unit confinement the domain already
# writes all keep working, because there is an init to run them.
#
# Seeds are PLURAL by design. Radicle's replication model gives every seed its
# own NID, which lives in the key rather than the address, so a container seed
# stands up ALONGSIDE a running host seed and neither cutover nor rollback
# exists: both are entries in every workstation's `connect` list until one is
# removed. `defaultSeedingPolicy = "allow"` is what lets a new seed pull the
# repositories across.
#
# The mirror is deliberately not part of this role. Two mirrors force-push the
# same refs, so it is the one radicle role that cannot overlap; it belongs on
# exactly one seed, added through `my` when that seed is chosen.

{ self }:

{
  # Architecture. A container has no hardware profile, so mkSystem's oci branch
  # needs this named -- see lib/mkSystem.nix.
  system

  # The node's radicle public key, as `keys/radicle.pub` contains it and
  # WITHOUT a trailing comment. Public data; the matching private key arrives
  # at runtime ALREADY DECRYPTED, from the host (see identityDir below). A
  # seed's NID is derived from this key, so a new seed means a new key means a
  # new NID -- which is exactly why standing one up beside another is safe.
, publicKey

  # The node name: the container's hostname AND, because tailscaled runs
  # inside, its name on the tailnet. The FULL name, not a suffix -- this used
  # to be a suffix onto "radicle-", which meant a caller naming its seed
  # `radicle-yoga-seed` (as ./builder.nix's naming argues it should) silently
  # got `radicle-radicle-yoga-seed`. Nothing catches that: the image builds,
  # the container runs, and the damage is that `externalAddresses` and
  # `seedHostname` then name a tailnet host that does not exist -- so the seed
  # advertises an address nobody can dial and its explorer fetches from
  # nowhere, both of which look like network faults rather than a typo.
, name ? "radicle-seed"

  # `<nid>@<host>:<port>` peers this seed dials, and the addresses it
  # advertises. A second seed lists the first here (and gets listed by it), so
  # the two replicate to each other.
, connect ? [ ]
, externalAddresses ? [ ]

  # Repositories this seed serves, as short-name -> RID for clone URLs.
, aliases ? { }

  # Where the browser reaches this seed's httpd API. Baked into the explorer
  # SPA at build time and fetched by the BROWSER, so it must be a name the
  # browser can resolve -- the tailnet MagicDNS name, never "localhost".
, seedHostname ? null

  # Tailnet identity. Tagged, because an OAuth-registered node must be, and
  # because a tagged node's key never expires -- a seed that silently drops off
  # the tailnet is a seed that stops replicating.
, tags ? [ "tag:radicle-seed" ]

  # The one directory the host bind-mounts into the container, read-only. It is
  # what makes the IMAGE identity-free and the CONTAINER identified: several
  # seeds can share one image and differ only in what is mounted here.
  #   node-key   the node's private key, ALREADY DECRYPTED by the host
  #
  # Decryption is the host's job because sops-install-secrets mounts a ramfs
  # for its secrets directory, which needs CAP_SYS_ADMIN -- see ./identity.nix
  # for why a role cannot have it. Any ciphertext the host keeps beside the
  # plaintext is its business, not the role's.
, identityDir ? "/var/lib/radicle-identity"

  # Auth key for unattended tailnet registration, as a FILE. Null leaves the
  # node to a manual `tailscale up`.
, tailscaleAuthKeyFile ? null

  # Extra `my` layers. A list, so a caller adds facts without re-splicing what
  # is below -- the mirror, extra seeded repositories, avatars.
, my ? [ ]
}:

self.lib.mkSystem {
  platform = "oci";
  inherit system;
  hostname = name;

  my = [
    {
      network.tailscale = {
        enable = true;
        inherit tags;
        authKeyFile = tailscaleAuthKeyFile;
      };

      infra.radicle = {
        enable = true;
        inherit publicKey;

        node = {
          inherit connect externalAddresses;
          # A seed exists to hold every peer's refs -- they are all ours.
          defaultSeedingPolicy = "allow";
        };

        httpd = {
          enable = true;
          inherit aliases;
          # The explorer is served from this same machine, which is what keeps
          # third-party JavaScript away from a private forge. It is its own
          # nginx inside the role, not the host's.
          explorer = {
            enable = true;
            inherit seedHostname;
          };
        };
      };
    }
  ]
  ++ my;

  # The identity contract: see ./identity.nix. A module rather than a `my`
  # layer because a layer is a plain attribute set and receives no module
  # arguments, so it cannot reach options outside `my.*`.
  extraModules = [ (import ./identity.nix identityDir) ];
}
