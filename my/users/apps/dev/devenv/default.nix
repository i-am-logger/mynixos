args:

(import ../../../../../lib/mk-app.nix).mkApp args {
  path = "dev.tools.devenv";
  option = {
    name = "devenv";
    default = false;
    description = "devenv development environment manager";
    persistedDirectories = [ ];
  };
  home = { pkgs, ... }: {
    home.packages = with pkgs; [
      devenv
    ];
  };
}
