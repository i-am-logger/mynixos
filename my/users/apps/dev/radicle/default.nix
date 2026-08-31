# Radicle CLI (rad, git-remote-rad) -- the per-user, cross-platform half of
# the forge. The system node / seed / CI / mirror machinery is Linux-only and
# lives in my/infra/radicle.
#
# The daemon half is Linux-only and lives in ./options-linux.nix + ./linux.nix:
# it needs a systemd user service, so on darwin the option must not exist at
# all rather than exist and do nothing. macOS gets the CLI, and `rad node
# start` by hand when wanted.
args:

(import ../../../../../lib/mk-app.nix).mkApp args {
  path = "dev.tools.radicle";
  option = {
    name = "radicle";
    default = false;
    description = "Radicle CLI (rad, git-remote-rad); per-user identity in ~/.radicle";
    persistedDirectories = [ ".radicle" ];
  };
  home = { pkgs, ... }: {
    home.packages = [ pkgs.radicle-node ];
  };
}
