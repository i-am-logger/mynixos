args:

(import ../../../../../lib/mk-app.nix).mkApp args {
  path = "graphical.sync.rclone";
  option = {
    name = "rclone";
    default = false;
    description = "rclone cloud sync";
    persistedDirectories = [ ".config/rclone" ];
  };
  home = { pkgs, ... }: {
    home.packages = with pkgs; [
      rclone
    ];
  };
}
