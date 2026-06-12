args:

(import ../../../../../lib/mk-app.nix).mkApp args {
  path = "dev.tools.kdiff3";
  home = { pkgs, ... }: {
    home.packages = with pkgs; [
      kdiff3
    ];
  };
}
