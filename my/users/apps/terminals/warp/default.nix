args:

(import ../../../../../lib/mk-app.nix).mkApp args {
  path = "graphical.terminals.warp";
  option = {
    name = "warp";
    default = false;
    description = "Warp terminal";
    persistedDirectories = [ ];
  };
  home = { pkgs, ... }: {
    home.packages = with pkgs; [
      warp-terminal
    ];
  };
}
