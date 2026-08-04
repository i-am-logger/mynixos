args:

(import ../../../../../lib/mk-app.nix).mkApp args {
  path = "terminal.fun.pipes";
  option = {
    name = "pipes";
    default = false;
    description = "Terminal eye candy (pipes, neo, asciiquarium)";
    persistedDirectories = [ ];
  };
  home = { pkgs, ... }: {
    home.packages = with pkgs; [
      pipes
      neo
      asciiquarium
    ];
  };
}
