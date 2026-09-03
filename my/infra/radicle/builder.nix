# What makes a node a BUILDER: it runs CI for the repositories it seeds.
#
# ACCEPTED RISK, stated here because this is the file that turns CI on: the
# broker hands the decrypted node key to an adapter that runs
# repository-supplied shell, so a recipe can read this node's key. No delivery
# mechanism reaches that. It is acceptable because a builder's key is disposable
# -- rotating it costs seconds -- and because `ci.trustedNids` pins exactly whose
# pushes may start a run. That is why a builder is its own machine with its own
# key rather than a service switched on beside a seed.
#
# Declared inside the submodule rather than written from a module, for the
# recursion reason ./seed.nix sets out. One consequence: this file cannot name
# `pkgs`, so the packages a builder adds to the CI adapter PATH are contributed
# from ./ci.nix, which already has pkgs and already renders that list.
{ lib, ... }:

{
  options.my.infra = lib.mkOption {
    type = lib.types.submodule {
      options.radicle = lib.mkOption {
        type = lib.types.submodule ({ config, ... }: {
          config = lib.mkIf config.builder.enable {
            # A builder seeds ONLY what it is told to, and that is a security
            # setting rather than a preference: every repository it seeds is one
            # whose CI recipe it will execute, so the set has to be a decision
            # rather than a side effect of what happens to be announced.
            node.defaultSeedingPolicy = lib.mkDefault "block";

            ci.enable = lib.mkDefault true;

            # A builder is the only machine its reports exist on, so it is the
            # only one that can serve them. Whatever fronts CI results proxies
            # here; nothing reads this machine's filesystem from outside, which
            # keeps the files owned by its own user instead of needing subuid
            # mappings matched by hand across a boundary.
            ci.serveReports.enable = lib.mkDefault true;
          };
        });
      };
    };
  };
}
