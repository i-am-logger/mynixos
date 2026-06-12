args:

(import ../../../../../lib/mk-app.nix).mkApp args {
  path = "graphical.terminals.warp";
  home = { pkgs, ... }: {
    home.packages = with pkgs; [
      warp-terminal
    ];
  };
}
