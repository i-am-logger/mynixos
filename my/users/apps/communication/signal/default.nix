args:

(import ../../../../../lib/mk-app.nix).mkApp args {
  path = "communication.messaging.signal";
  home = { pkgs, ... }: {
    home.packages = with pkgs; [
      signal-desktop
    ];
  };
}
