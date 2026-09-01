# The runtime identity contract every radicle role shares.
#
# The IMAGE is identity-free and the CONTAINER is identified. That is not
# tidiness: it is what makes several builders (or a second seed) share one image
# and differ only in what is bind-mounted at `identityDir`. Baking a key into
# the image would make the image the identity, and radicle's whole model is that
# the NID lives in the key.
#
# What the host mounts there, read-only:
#
#   node-key   the node's private key, ALREADY DECRYPTED
#
# The node's PUBLIC key is not here. It is public data, it is what a peer pins
# in `<nid>@host:port`, and `my.infra.radicle.publicKey` takes it as a string --
# so it belongs in the role's arguments, in the clear, beside the connect list
# it has to agree with.
#
# WHY THE KEY ARRIVES DECRYPTED, which is not what an earlier version of this
# file did. It used to mount an age key and a sops file and let sops-nix decrypt
# inside the container. That cannot work: sops-install-secrets mounts a ramfs at
# the secrets directory -- a tmpfs under `sops.useTmpfs`, but still `mount(2)`
# -- and that needs CAP_SYS_ADMIN. A role runs repository-supplied shell, so
# withholding SYS_ADMIN is the entire reason it is a separate role with a
# disposable key. The two requirements cannot both be met inside the container,
# so decryption moves OUT, to a host that has the capability, and the plaintext
# is bind-mounted in.
#
# The failure it produced was not obvious from either end: sops reported
# `failed to mount filesystem for secrets: cannot mount: operation not
# permitted`, which reads as a sops problem, from an activation script, in a
# container whose logs are a nested boot.
#
# What that costs, stated plainly: the key exists decrypted at a stable path for
# as long as the container runs, rather than only inside one unit's credentials
# directory. It is still encrypted at rest, it still reaches radicle-node
# through `LoadCredential` -- read by systemd as root before `User=` drops, so
# the radicle user never holds it -- and it still never enters the store. The
# same is already true of /run/secrets on every host here that uses sops at all.

identityDir:

{
  my.infra.radicle.privateKeyFile = "${identityDir}/node-key";

  # Deliberately NOT enabling my.secrets. It is not merely unnecessary here:
  # enabling it is what puts sops-install-secrets in the activation path, and
  # my/infra/radicle asserts the two are mutually exclusive for that reason.
}
