args:

(import ../../../../../lib/mk-app.nix).mkApp args {
  path = "art.drawing.krita";
  option = {
    name = "Krita";
    default = false;
    description = "Krita digital painting";
    persistedDirectories = [ ".config/krita" ];
  };
  home = { pkgs, ... }: {
    home.packages = [ pkgs.krita ];
  };
}
