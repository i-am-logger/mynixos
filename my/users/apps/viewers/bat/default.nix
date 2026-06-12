args:

(import ../../../../../lib/mk-app.nix).mkApp args {
  path = "terminal.viewers.bat";
  home = _: {
    programs.bat = {
      enable = true;
    };
  };
}
