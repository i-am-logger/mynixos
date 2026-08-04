args:

(import ../../../../../lib/mk-app.nix).mkApp args {
  path = "art.modeling.blender";
  option = {
    name = "Blender";
    default = false;
    description = "Blender 3D suite";
    persistedDirectories = [ ".config/blender" ];
  };
  home = { pkgs, ... }: {
    home.packages = [ pkgs.blender ];
  };
}
