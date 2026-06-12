args:

(import ../../../../../lib/mk-app.nix).mkApp args {
  path = "communication.messaging.slack";
  unfree = [ "slack" ];
  home = { pkgs, ... }: {
    home.packages = with pkgs; [
      slack
    ];
  };
}
