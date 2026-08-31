# The read-only radicle profile a non-node unit needs at RAD_HOME.
#
# `rad` and git-remote-rad's READ path want config.json and keys/radicle.pub
# to exist at RAD_HOME -- and on a real host those exist only inside the node
# unit's mount namespace, bind-mounted from the store. Any sibling unit that
# talks to storage (declarative seeding, the GitHub mirror) therefore has to
# bind the same two files.
#
# The private key is deliberately NOT among them: the read path needs no
# signature (verified against a live profile -- a keyless, read-only RAD_HOME
# fetches every branch and tag through git-remote-rad), and materialising it
# anywhere outside the node/broker namespaces would hand it to units that
# have no business signing.
#
# Defined once here because the two consumers must not drift: if heartwood
# ever needs a third file, the unit that fails first must not be fixed alone.
{ config, pkgs, publicKey }:

{
  radHome = "/var/lib/radicle";

  bindReadOnlyPaths = [
    "${config.services.radicle.configFile}:/var/lib/radicle/config.json"
    "${pkgs.writeText "radicle.pub" publicKey}:/var/lib/radicle/keys/radicle.pub"
  ];
}
