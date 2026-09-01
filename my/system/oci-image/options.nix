# Options for the OCI image emitter. A plain module declaring `options.my` -- the
# second shape CLAUDE.md describes -- rather than a fragment behind
# mkOptionsModule, because ./default.nix is what implements it and must import it
# directly: default.nix names `pkgs` (it calls dockerTools), and an option module
# that names `pkgs` forces `_module.args.pkgs`, which depends on
# `config.nixpkgs`. Splitting the declaration out is what keeps that away from
# the option tree.
{ lib, ... }:

{
  options.my.system.ociImage = {
    tag = lib.mkOption {
      type = lib.types.str;
      default = "reference";
      example = "latest";
      description = ''
        Tag for the image `system.build.image` produces. The repository half of
        the name is the hostname, so this is the only thing distinguishing two
        images built for the same role.

        The default is deliberately NOT "latest". A role image is only as
        trustworthy as the identity it was built for, and the reference fleet in
        roles/radicle is built for keys whose private halves were destroyed --
        it exists to be inspected, never to run. Defaulting to "latest" would
        let such an image occupy, in any container runtime, exactly the tag a
        real deployment's image lands on, where nothing distinguishes the two.

        A real deployment sets this, along with the identity it is deploying.
      '';
    };
  };
}
