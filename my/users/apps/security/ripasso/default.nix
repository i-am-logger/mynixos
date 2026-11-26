args:

# ripasso, a terminal UI for a pass store.
(import ../../../../../lib/mk-app.nix).mkApp args {
  path = "security.passwords.ripasso";
  option = {
    name = "ripasso";
    default = false;
    description = "ripasso, a terminal UI for a pass store";
  };
  home = { pkgs, ... }: {
    home.packages = [
      # nixpkgs' cargo hook now makes -sys crates link system libraries,
      # and ripasso's libgit2-sys 0.17 wants libgit2 1.8 where nixpkgs has
      # 1.9. Opting out builds it as before, with its bundled 1.8.1.
      (pkgs.ripasso-cursive.overrideAttrs { dontCargoUseSystemLibs = true; })
    ];
  };
}
