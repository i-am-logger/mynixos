args:

(import ../../../../../lib/mk-app.nix).mkApp args {
  path = "graphical.utils.calculator";
  home = { pkgs, ... }: {
    home.packages = with pkgs; [
      qalculate-gtk # Calculator with qalc CLI
    ];
  };
}
