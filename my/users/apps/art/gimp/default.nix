args:

(import ../../../../../lib/mk-app.nix).mkApp args {
  path = "art.editing.gimp";
  option = {
    name = "GIMP";
    default = false;
    description = "GIMP image editor";
    persistedDirectories = [ ".config/GIMP" ];
  };
  home = { pkgs, ... }: {
    home.packages = [ pkgs.gimp ];
  };
}
