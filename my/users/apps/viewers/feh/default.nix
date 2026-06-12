args:

(import ../../../../../lib/mk-app.nix).mkApp args {
  path = "terminal.viewers.feh";
  home = { pkgs, lib, ... }: {
    home.packages = with pkgs; [
      feh
    ];

    programs.feh.enable = lib.mkDefault true;
  };
}
