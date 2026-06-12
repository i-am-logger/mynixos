args:

(import ../../../../../lib/mk-app.nix).mkApp args {
  path = "terminal.fun.pipes";
  home = { pkgs, ... }: {
    home.packages = with pkgs; [
      pipes
      neo
      asciiquarium
    ];
  };
}
