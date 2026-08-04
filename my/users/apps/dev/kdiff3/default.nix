args:

(import ../../../../../lib/mk-app.nix).mkApp args {
  path = "dev.tools.kdiff3";
  option = {
    name = "kdiff3";
    default = false;
    description = "KDiff3 diff tool";
    persistedDirectories = [ ];
  };
  home = { pkgs, ... }: {
    home.packages = with pkgs; [
      kdiff3
    ];
  };
}
