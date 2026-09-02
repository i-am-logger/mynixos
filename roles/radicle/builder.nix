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
  # at runtime ALREADY DECRYPTED, from the host (see identityDir below).
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
  #   node-key   the node's private key, ALREADY DECRYPTED by the host
  #
  # Decryption is the host's job because sops-install-secrets mounts a ramfs
  # for its secrets directory, which needs CAP_SYS_ADMIN -- exactly the
  # capability a role running repository-supplied shell must not have. See
  # ./identity.nix.
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

        # No httpd and no explorer: a builder serves no repositories and reads
        # none. It does serve its own CI reports, because it is the only machine
        # they exist on -- an earlier version of this comment said they were
        # "published by the broker and read on a seed", which assumed job COBs
        # carry the result. On this fleet they do not: the explorer reads reports
        # off DISK, so moving CI here moved the reports with it.
        ci = {
          enable = true;
          inherit trustedNids;

          # A builder is the only place its reports exist, so it is the only
          # place that can serve them. Whatever fronts CI results proxies here;
          # nothing reads this container's filesystem from outside, which is what
          # keeps the files owned by the container's own user instead of needing
          # subuid mappings matched by hand across the boundary.
          serveReports.enable = true;
        };
      };
    }
  ]
  ++ my;

  # Modules, for what a `my` layer cannot express: a layer is a plain
  # attribute set and receives no module arguments, so it cannot name `pkgs`
  # or reach options outside `my.*`.
  #
  # The identity contract: see ./identity.nix.
  #
  # A BUILDER CARRIES ITS OWN TOOLCHAIN. `nix` is already unconditional on the
  # adapter PATH (my/infra/radicle/ci.nix); `devenv` is added here because it
  # is what a builder IS, not something the host lends it. A host that had to
  # supply it would make the role depend on where it happens to run -- the
  # exact coupling this design exists to remove -- and the same role on another
  # machine would then build differently, silently.
  #
  # Written as a module rather than passed in as a derivation so it is
  # evaluated by THIS system and gets THIS system's pkgs. A package handed in
  # from the host would embed the host's package set into a different machine,
  # which works only while the two happen to share a nixpkgs and an
  # architecture.
  extraModules = [
    (import ./identity.nix identityDir)
    ({ pkgs, ... }: {
      my.infra.radicle.ci.adapters.native.extraRuntimePackages = [ pkgs.devenv ];
    })
  ];
}
