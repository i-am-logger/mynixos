# Temporary overlays for upstream nixpkgs bugs that block evaluation.
#
# Everything in here should be removable. Each entry names the upstream fix it
# stands in for, so it is obvious when it can go.
#
# Imported directly by ../nixpkgs-fixes/default.nix, and by the test suites,
# which build their own pkgs. It has to be applied in
# three places that do not share a pkgs instance:
#
#   1. `nixpkgs.overlays`                       (system pkgs)
#   2. `home-manager.users.<n>.nixpkgs.overlays` (mkSystem does not set
#      useGlobalPkgs, so home-manager instantiates its own)
#   3. the test harnesses, which `import nixpkgs` directly and load
#      nixos/modules/misc/nixpkgs/read-only.nix — that suppresses
#      `nixpkgs.overlays` outright, so a module can never reach them
#
# my/system/nixpkgs-fixes wires up 1 and 2.
_final: prev: {
  # tree-sitter: `replaceStrings`' second argument must be a list.
  #
  #   pkgs/by-name/tr/tree-sitter/package.nix:85
  #   replaceHyphens = lib.strings.replaceStrings [ "-" ] "_";
  #                                                        ^^^ should be [ "_" ]
  #
  # Introduced by nixpkgs cbd756b6a804 / 102526a4d592 ("tree-sitter: partially
  # apply removePrefix calls", 2026-07-20). Any use of `tree-sitter.withPlugins`
  # — which my/users/apps/editors/helix does — then fails to evaluate with
  # `expected a list but found a string: "_"`.
  #
  # Fixed upstream in master by 1170af5687be ("tree-sitter: fix evaluation
  # error", 2026-07-30) but not yet on nixos-unstable. DROP THIS FILE, and
  # my/system/nixpkgs-fixes, once the channel catches up.
  tree-sitter = prev.tree-sitter.overrideAttrs (old: {
    passthru = old.passthru // {
      # Reimplements mkGrammarLinkFarm with the list argument corrected.
      withPlugins =
        grammarFn:
        prev.linkFarm "grammars" (
          map
            (drv:
            let
              name = prev.lib.strings.getName drv;
              stripped = prev.lib.strings.removeSuffix "-grammar"
                (prev.lib.strings.removePrefix "tree-sitter-" name);
            in
            {
              name = prev.lib.strings.replaceStrings [ "-" ] [ "_" ] stripped + ".so";
              path = "${drv}/parser";
            })
            (grammarFn prev.tree-sitter.grammarsScope.derivations)
        );
    };
  });
}
