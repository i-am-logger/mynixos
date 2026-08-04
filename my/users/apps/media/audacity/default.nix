args:

(import ../../../../../lib/mk-app.nix).mkApp args {
  path = "media.editors.audacity";
  option = {
    name = "Audacity";
    default = false;
    description = "Audacity audio editor";
    persistedDirectories = [ ".config/audacity" ];
  };
  home = { pkgs, ... }: {
    home.packages = [ pkgs.audacity ];
  };
}
