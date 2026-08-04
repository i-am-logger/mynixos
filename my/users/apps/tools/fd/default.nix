args:

(import ../../../../../lib/mk-app.nix).mkApp args {
  path = "terminal.tools.fd";
  option = {
    name = "fd";
    default = true;
    description = "fd file finder. On by default because my/users/terminal defines `ff` and `ffd` in terms of it, and fzf uses it for its file and directory widgets.";
  };
  home = _: {
    programs.fd.enable = true;
  };
}
