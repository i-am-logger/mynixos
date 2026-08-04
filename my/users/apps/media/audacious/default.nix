args:

(import ../../../../../lib/mk-app.nix).mkApp args {
  path = "media.players.audacious";
  option = {
    name = "audacious";
    default = false;
    description = "Audacious music player";
    persistedDirectories = [ ];
  };
  home = { pkgs, ... }: {
    home.packages = with pkgs; [
      audacious
    ];
  };
}
