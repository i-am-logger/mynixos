args:

(import ../../../../../lib/mk-app.nix).mkApp args {
  path = "media.players.musikcube";
  home = { pkgs, ... }: {
    home.packages = with pkgs; [
      musikcube
    ];
  };
}
