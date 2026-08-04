args:

(import ../../../../../lib/mk-app.nix).mkApp args {
  path = "art.drawing.inkscape";
  option = {
    name = "Inkscape";
    default = false;
    description = "Inkscape vector graphics";
    persistedDirectories = [ ".config/inkscape" ];
  };
  home = { pkgs, ... }: {
    home.packages = [ pkgs.inkscape ];
  };
}
