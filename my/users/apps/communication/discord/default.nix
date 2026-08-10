# Discord on Linux: the nixpkgs derivation, like any other app.
#
# The option is declared in ./options.nix rather than in this spec, because
# ./darwin.nix implements the same option a completely different way. See there
# for why macOS cannot use this derivation.
#
# Imported only by platforms/linux.nix.
args:

(import ../../../../../lib/mk-app.nix).mkApp args {
  path = "communication.messaging.discord";
  unfree = [ "discord" ];
  home = { pkgs, ... }: {
    home.packages = [ pkgs.discord ];
  };
}
