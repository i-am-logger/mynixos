args:

(import ../../../../../lib/mk-app.nix).mkApp args {
  path = "graphical.terminals.alacritty";
  home = _: {
    programs.alacritty.enable = true;
  };
}
