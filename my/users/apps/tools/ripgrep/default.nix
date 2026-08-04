args:

(import ../../../../../lib/mk-app.nix).mkApp args {
  path = "terminal.tools.ripgrep";
  option = {
    name = "ripgrep";
    default = true;
    description = "ripgrep recursive search";
  };
  home = _: {
    programs.ripgrep.enable = true;
  };
}
