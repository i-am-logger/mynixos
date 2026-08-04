args:

(import ../../../../../lib/mk-app.nix).mkApp args {
  path = "media.editors.kdenlive";
  option = {
    name = "Kdenlive";
    default = false;
    description = "Kdenlive video editor";
    persistedDirectories = [ ".local/share/kdenlive" ];
  };
  home = { pkgs, ... }: {
    home.packages = [ pkgs.kdenlive ];
  };
}
