args:

(import ../../../../../lib/mk-app.nix).mkApp args {
  path = "media.players.musikcube";
  option = {
    name = "musikcube";
    default = false;
    description = "musikcube music player";
    persistedDirectories = [ ];
  };
  home = { pkgs, ... }: {
    home.packages = with pkgs; [
      musikcube
    ];
  };
}
