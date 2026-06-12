args:

(import ../../../../../lib/mk-app.nix).mkApp args {
  path = "graphical.editors.marktext";
  home = { pkgs, ... }: {
    home.packages = with pkgs; [
      marktext
    ];
  };
}
