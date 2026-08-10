args:

(import ../../../../../lib/mk-app.nix).mkApp args {
  path = "media.players.qobine";
  option = {
    name = "qobine";
    default = false;
    description = "qobine terminal player for Qobuz (requires a Qobuz subscription)";
    # Credentials, playback queue and settings live in a sqlite database
    # under $XDG_DATA_HOME/qobine.
    persistedDirectories = [ ".local/share/qobine" ];
  };
  home = { pkgs, ... }: {
    home.packages = [ (pkgs.callPackage ../../../../../packages/qobine { }) ];
  };
}
