args:

(import ../../../../../lib/mk-app.nix).mkApp args {
  path = "media.players.audacious";
  home = { pkgs, ... }: {
    home.packages = with pkgs; [
      audacious
    ];
  };
}
