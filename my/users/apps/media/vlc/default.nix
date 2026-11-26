args:

# VLC. Linux only: nixpkgs' vlc does not build on darwin.
(import ../../../../../lib/mk-app.nix).mkApp args {
  path = "media.players.vlc";
  option = {
    name = "vlc";
    default = false;
    description = "VLC media player";
  };
  home = { pkgs, ... }: {
    home.packages = [ pkgs.vlc ];
  };
}
