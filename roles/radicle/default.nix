# The Radicle roles, and the reference fleet this flake builds images for.
#
# Two things live here, and they are not the same thing:
#
#   * `builder` and `seed` -- the ROLE FUNCTIONS. Data-free, and the reusable
#     half: a consumer flake calls one with its own identities and reads
#     `.config.system.build.image`. This is the real deployment path, and the
#     one `virtualisation.oci-containers`' `imageStream` consumes.
#
#   * `images` -- the REFERENCE FLEET, exposed as this flake's own packages so
#     the emitter is proved by a real build rather than by evaluation alone.
#
# THE REFERENCE IDENTITIES BELOW ARE NOT DEPLOYABLE, and cannot be made so by
# accident. Each public key was generated for this file and its private half
# destroyed, so no `radicle/node-key` anywhere decrypts to a matching secret
# key: a container started from a reference image fails at once with a key
# mismatch rather than coming up as somebody. A real deployment does not edit
# these -- it calls the role functions with its own `rad self` output.

{ self }:

let
  builder = import ./builder.nix { inherit self; };
  seed = import ./seed.nix { inherit self; };

  # A builder's lane is the architecture it builds NATIVELY. It is part of the
  # role's name because builders are the plural role -- "which lane" is the
  # question you ask of a builder, and `radicle-x64-builder` answers it in the
  # hostname, the node alias and the image tag at once.
  lanes = {
    x86_64-linux = "x64";
    aarch64-linux = "arm64";
  };

  # Reference identities. Generated for this file; private halves destroyed.
  reference = {
    seedPublicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIG/jsTG5V8rh04TZVk4qkMWawNvHMLNRMfRq+cZuR8Es";
    seedNid = "z6Mkmz2fvyw9TSp27Vegnfrzq4NfyCshTbBqBvpMBKCYGREs";
    builderPublicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAmVvY9KBGPf1qfF1PUXHwKmHjCa+adnk0OG8YBv1825";
    # The delegate whose pushes may trigger CI. On a real fleet this is a
    # workstation's `rad self --nid`, and getting it wrong fails SAFE: the
    # broker's trigger filter simply never matches.
    delegateNid = "z6MkhwDCinCBnfK8E8kEGGfiuBXHZcf2qEmBX4AteNtnA4HC";
    seedAddress = "radicle-seed:8776";
  };
in
{
  inherit builder seed;

  # The reference fleet for one architecture, as { <name> = <image>; }. Empty
  # for a system with no lane name, which is the honest answer: there is no
  # such thing as a builder that does not say what it builds.
  images = system:
    if !(lanes ? ${system}) then { }
    else
      let
        lane = lanes.${system};
      in
      {
        "radicle-${lane}-builder-image" =
          (builder {
            inherit system lane;
            publicKey = reference.builderPublicKey;
            trustedNids = [ reference.delegateNid ];
            connect = [ "${reference.seedNid}@${reference.seedAddress}" ];
          }).config.system.build.image;

        radicle-seed-image =
          (seed {
            inherit system;
            publicKey = reference.seedPublicKey;
            externalAddresses = [ reference.seedAddress ];
          }).config.system.build.image;
      };
}
