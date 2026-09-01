# The runtime identity contract every radicle role shares.
#
# The IMAGE is identity-free and the CONTAINER is identified. That is not
# tidiness: it is what makes several builders (or a second seed) share one
# image and differ only in what is bind-mounted at `identityDir`. Baking a key
# into the image would make the image the identity, and radicle's whole model
# is that the NID lives in the key.
#
# What the host mounts there, read-only:
#
#   age.key       the age key sops decrypts with, for this role alone
#   secrets.yaml  the sops file holding `radicle/node-key`
#
# The node's PUBLIC key is not here. It is public data, it is what a peer pins
# in `<nid>@host:port`, and `my.infra.radicle.publicKey` takes it as a string --
# so it belongs in the role's arguments, in the clear, beside the connect list
# it has to agree with.
#
# Both paths are runtime paths, which `my.secrets` requires by default rather
# than merely permits -- see my/secrets/options.nix. This file used to switch
# `sops.validateSopsFiles` off by hand to get that, back when a role was the
# only thing in the fleet keeping secrets out of the store; the option now
# tracks `my.secrets.allowSecretsInStore`, so the role gets it for free and
# setting it here would be a second definition of the same switch.
#
# What that costs is not obvious from the option's name, and is worth stating
# once because it applies to every consumer of my.secrets now, not just roles:
#
#   * the manifest derivation's checkPhase drops from `-check-mode=sopsfile` to
#     `-check-mode=manifest` (sops-nix modules/sops/manifest-for.nix:56), so the
#     EVAL-time check that the named key `radicle/node-key` actually exists in
#     the file goes with it. That one does move to activation, where sops-nix
#     fails the unit -- but a secret ADDED to a role later is not eval-checked
#     either, and it is easy to assume otherwise;
#   * the `secret.uid`/`gid` vs `owner`/`group` conflict assertions
#     (modules/sops/default.nix:447-465) simply disappear. They have nothing to
#     do with store paths. Nothing here sets uid/gid, so nothing is broken
#     today; a role that starts setting them loses the check that they agree.
#
# sops-nix has no per-secret toggle, so this is the minimum loosening available.

identityDir:

{
  my.secrets = {
    enable = true;
    ageKeyFile = "${identityDir}/age.key";
    defaultSopsFile = "${identityDir}/secrets.yaml";
  };
}
