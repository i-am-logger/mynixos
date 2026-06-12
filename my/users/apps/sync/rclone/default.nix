args:

(import ../../../../../lib/mk-app.nix).mkApp args {
  path = "graphical.sync.rclone";
  home = { pkgs, ... }: {
    home.packages = with pkgs; [
      rclone
    ];
  };
}
