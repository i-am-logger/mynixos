args:

(import ../../../../../lib/mk-app.nix).mkApp args {
  path = "communication.messaging.element";
  home = { pkgs, ... }: {
    home.packages = with pkgs; [
      element-desktop
    ];
  };
}
