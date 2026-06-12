args:

(import ../../../../../lib/mk-app.nix).mkApp args {
  path = "graphical.utils.imagemagick";
  home = { pkgs, ... }: {
    home.packages = with pkgs; [
      imagemagick
    ];
  };
}
