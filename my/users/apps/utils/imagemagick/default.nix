args:

(import ../../../../../lib/mk-app.nix).mkApp args {
  path = "graphical.utils.imagemagick";
  option = {
    name = "ImageMagick";
    default = false;
    description = "ImageMagick image manipulation";
    persistedDirectories = [ ];
  };
  home = { pkgs, ... }: {
    home.packages = with pkgs; [
      imagemagick
    ];
  };
}
