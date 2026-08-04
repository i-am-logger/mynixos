args:

(import ../../../../../lib/mk-app.nix).mkApp args {
  path = "art.editing.darktable";
  option = {
    name = "darktable";
    default = false;
    description = "darktable RAW photo workflow";
    persistedDirectories = [ ".config/darktable" ];
  };
  home = { pkgs, ... }: {
    home.packages = [ pkgs.darktable ];
  };
}
