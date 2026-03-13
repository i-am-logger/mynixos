_:
{
  projectRootFile = "flake.nix";

  # Nix formatting (same formatter you had before)
  # Shell formatting and linting
  # YAML formatting (for CI workflows)
  programs = {
    nixpkgs-fmt.enable = true;
    shfmt.enable = true;
    shellcheck.enable = true;
    yamlfmt.enable = true;
  };
}
