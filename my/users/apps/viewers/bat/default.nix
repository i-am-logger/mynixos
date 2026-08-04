args:

(import ../../../../../lib/mk-app.nix).mkApp args {
  path = "terminal.viewers.bat";
  option = {
    name = "bat";
    default = false;
    description = "Bat file viewer";
    persistedDirectories = [ ];
  };
  home = _: {
    programs.bat = {
      enable = true;
    };
  };
}
