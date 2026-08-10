_:
{
  projectRootFile = "flake.nix";

  programs = {
    # Nix
    nixpkgs-fmt.enable = true;

    # statix and deadnix were separate CI jobs, which meant `nix fmt` could pass
    # while CI failed on the same tree -- the drift this file exists to prevent.
    # Run from here they are part of `nix flake check`'s `formatting` check, so
    # the local command and the workflow cannot disagree.
    statix.enable = true;
    deadnix = {
      enable = true;
      # An underscore prefix is how this tree already says "bound, deliberately
      # unused" (`_name:` in every mapAttrs, `_final: prev:` in the overlays), so
      # honouring it is not a loosening -- it is the existing convention.
      no-underscore = false;
    };

    # Shell
    shfmt.enable = true;
    shellcheck.enable = true;

    # YAML (CI workflows)
    yamlfmt.enable = true;
  };
}
