# The Radicle CI BUILDER role: a node with the CI broker switched on.
#
# `my.infra.radicle` is reused UNCHANGED. The broker's `LoadCredential`, its
# `StateDirectory`, the native adapters' trigger filters and the per-unit
# confinement around the node all come from that domain and all keep working,
# because a role is a machine with an init rather than a single process in a
# `FROM scratch` image.
#
# Builders are the plural role that matters: more of them is more CI lanes
# across repositories, and each is its own tailnet node with its own radicle
# identity. `lane` is what tells them apart -- "x64" is the architecture a lane
# builds natively, not the architecture of this file.
#
# ACCEPTED RISK, restated here because this is the file that turns CI on: the
# broker hands the decrypted node key to an adapter that runs repository-
# supplied shell, so a recipe can read the builder's key. No delivery mechanism
# reaches that. It is acceptable because it is a BUILDER's key -- disposable,
# and rotating it costs seconds -- and because `trustedNids` below pins exactly
# whose pushes may start a run.

{ self }:

{
  # Architecture. A container has no hardware profile, so mkSystem's oci branch
  # needs this named -- see lib/mkSystem.nix.
  system

  # The node's radicle public key, as `keys/radicle.pub` contains it and
  # WITHOUT a trailing comment. Public data; the matching private key arrives
  # at runtime through sops (see identityDir below).
, publicKey

  # NIDs whose pushes and patches may trigger CI. MANDATORY, and asserted
  # non-empty by my/infra/radicle/ci.nix: without a Node trigger filter, anyone
  # who can reach a seeded repository executes arbitrary code here.
, trustedNids

  # Which lane this builder is. Becomes the hostname and the node alias.
, lane ? "x64"

  # The node name: the container's hostname AND, because tailscaled runs
  # inside, its name on the tailnet. Defaults to the lane alone, which is
  # unique on ONE host. A fleet running builders on several hosts wants the
  # host in it: a tailnet name must be unique fleet-wide, and tailscale does
  # not reject a collision -- it silently appends -1, so two hosts' builders
  # become indistinguishable in exactly the place you would look to tell
  # them apart.
  #
  # Naming a role after where it runs is in slight tension with a role being
  # PLACED rather than welded to a host. Uniqueness wins: the identity is the
  # NID, not the name, so moving a role means re-registering anyway.
, name ? "radicle-${lane}-builder"

  # `<nid>@<host>:<port>` seeds this builder dials. A builder DIALS OUT and is
  # never dialed, so it advertises no external addresses at all.
, connect ? [ ]

  # Tailnet identity. Tag the builders: network reach on a tailnet is entirely
  # ACL policy, and an untagged builder can otherwise reach every other node.
, tags ? [ "tag:radicle-builder" ]

  # The one directory the host bind-mounts into the container, read-only. It is
  # what makes the IMAGE identity-free and the CONTAINER identified: several
  # builders can share one image and differ only in what is mounted here.
  #   age.key       sops age key for this role
  #   secrets.yaml  sops file holding `radicle/node-key`
, identityDir ? "/var/lib/radicle-identity"

  # Auth key for unattended tailnet registration, as a FILE. Null leaves the
  # node to a manual `tailscale up`.
, tailscaleAuthKeyFile ? null

  # Extra `my` layers. A list, so a caller adds facts without re-splicing what
  # is below -- more adapters, extra runtime packages, a remote builder.
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
          inherit connect;
          # A builder seeds only what it is told to: it fetches the repository
          # a job names, and has no reason to hold the fleet's refs.
          defaultSeedingPolicy = "block";
        };

        # No httpd and no explorer. A builder serves nothing; its reports are
        # published by the broker and read on a seed.
        ci = {
          enable = true;
          inherit trustedNids;
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
