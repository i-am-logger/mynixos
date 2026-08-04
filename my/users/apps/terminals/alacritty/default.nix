args:

(import ../../../../../lib/mk-app.nix).mkApp args {
  path = "graphical.terminals.alacritty";
  option = {
    name = "alacritty";
    default = false;
    description = "Alacritty terminal";
    persistedDirectories = [ ];
  };
  home = _: {
    programs.alacritty.enable = true;
  };
}
