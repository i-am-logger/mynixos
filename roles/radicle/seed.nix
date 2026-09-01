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
  # at runtime through sops (see identityDir below). A seed's NID is derived
  # from this key, so a new seed means a new key means a new NID -- which is
  # exactly why standing one up beside another is safe.
, publicKey

  # Distinguishes several seeds. Becomes the hostname and the node alias.
, name ? "seed"

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
  #   age.key       sops age key for this role
  #   secrets.yaml  sops file holding `radicle/node-key`
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
  hostname = "radicle-${name}";

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
  # layer because it also has to switch sops-nix's store-path check off, which
  # is not a `my.*` option and should not become one -- it is a fact about how
  # THIS deployment delivers the file, not about what mynixos configures.
  extraModules = [ (import ./identity.nix identityDir) ];
}
