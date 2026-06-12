args:

(import ../../../../../lib/mk-app.nix).mkApp args {
  path = "art.drawing.mypaint";
  home = { pkgs, ... }: {
    home.packages = with pkgs; [
      mypaint
    ];
  };
}
