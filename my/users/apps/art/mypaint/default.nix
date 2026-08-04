args:

(import ../../../../../lib/mk-app.nix).mkApp args {
  path = "art.drawing.mypaint";
  option = {
    name = "mypaint";
    default = false;
    description = "MyPaint drawing application";
    persistedDirectories = [ ];
  };
  home = { pkgs, ... }: {
    home.packages = with pkgs; [
      mypaint
    ];
  };
}
