args:

(import ../../../../../lib/mk-app.nix).mkApp args {
  path = "dev.tools.devenv";
  home = { pkgs, ... }: {
    home.packages = with pkgs; [
      devenv
    ];
  };
}
