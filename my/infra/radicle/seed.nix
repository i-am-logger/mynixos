# What makes a node a SEED: it holds every peer's refs, and serves them.
#
# Three settings, and they were the whole of roles/radicle/seed.nix's `my` layer
# once its system-building half is removed. Everything else that file carried --
# the tailnet identity, the key, who to dial, what to advertise -- belongs to the
# machine, not to the service, and lives in the consumer flake's system.
#
# WHY THIS IS AN OPTION DECLARATION AND NOT A MODULE. The obvious shape --
# `mkIf (cfg.enable && cfg.seed.enable) { my.infra.radicle.node... = ... }` --
# is an infinite recursion, and the repo already records why:
# my/network/openssh/default.nix:48-64 explains that `my.network` is ONE
# submodule option, so reading any leaf merges every definition of the whole
# thing, including the one the reading module is itself producing. `my.infra` is
# the same. Declaring the defaults INSIDE the submodule instead means `config`
# refers to the submodule's own config, and the cycle never forms -- the shape
# my/users/terminal/mynixos.nix uses for exactly this reason.
#
# mkDefault throughout, which is half the point of moving these here. As role
# values they were plain, so a consumer who set `node.defaultSeedingPolicy`
# themselves got "has conflicting definition values" rather than an override --
# the opposite of the guarantee this repo makes about defaults.
{ lib, ... }:

{
  options.my.infra = lib.mkOption {
    type = lib.types.submodule {
      options.radicle = lib.mkOption {
        type = lib.types.submodule ({ config, ... }: {
          config = lib.mkIf config.seed.enable {
            # A seed exists to hold every peer's refs -- they are all ours.
            # Without this a seed accepts only what it has been told about,
            # which is a workstation's policy wearing a seed's name.
            node.defaultSeedingPolicy = lib.mkDefault "allow";

            # Held refs nobody can read are a backup, not a seed. httpd is the
            # API and the explorer is the page a person opens; both are served
            # from this same machine, which is what keeps third-party JavaScript
            # away from a private forge.
            httpd.enable = lib.mkDefault true;
            httpd.explorer.enable = lib.mkDefault true;
          };
        });
      };
    };
  };
}
