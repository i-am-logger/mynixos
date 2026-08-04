args:

(import ../../../../../lib/mk-app.nix).mkApp args {
  path = "graphical.utils.calculator";
  option = {
    name = "calculator";
    default = false;
    description = "Calculator (qalculate)";
    persistedDirectories = [ ];
  };
  home = { pkgs, ... }: {
    home.packages = with pkgs; [
      qalculate-gtk # Calculator with qalc CLI
    ];
  };
}
