# Radicle CLI (rad, git-remote-rad) -- the per-user, cross-platform half of
# the forge. The system node / seed / CI / mirror machinery is Linux-only and
# lives in my/infra/radicle.
#
# The daemon half is Linux-only and lives in ./options-linux.nix + ./linux.nix:
# it needs a systemd user service, so on darwin the option must not exist at
# all rather than exist and do nothing. macOS gets the CLI, and `rad node
# start` by hand when wanted.
{ lib, ... }@args:

(import ../../../../../lib/mk-app.nix).mkApp args {
  path = "dev.tools.radicle";
  option = {
    name = "radicle";
    default = false;
    description = "Radicle CLI (rad, git-remote-rad); per-user identity in ~/.radicle";
    persistedDirectories = [ ".radicle" ];
    extraOptions = {
      # radicle-httpd -- and therefore the web explorer -- is a PUBLIC gateway:
      # it serves public repos and 404s private ones. These two read the local
      # node directly instead, so they are the only way to browse a private
      # repo, which on this fleet is most of them.
      tui = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "rad-tui: terminal browser for repos, patches and issues (private repos included).";
      };
      desktop = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "radicle-desktop: GUI browser reading the local node (private repos included).";
      };
      job = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          rad-job: read CI results. Job records are COBs that replicate like
          any other, so this reads runs from ANY machine on the network, not
          just the one that built them -- and it is the only way to see them,
          since the explorer's API serves repos, not jobs.
        '';
      };
    };
  };
  home = { cfg, pkgs, lib, ... }: {
    home.packages = [ pkgs.radicle-node ]
      ++ lib.optional cfg.tui pkgs.radicle-tui
      ++ lib.optional cfg.desktop pkgs.radicle-desktop
      ++ lib.optional cfg.job pkgs.radicle-job;
  };
}
