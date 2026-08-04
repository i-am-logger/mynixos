args:

(import ../../../../../lib/mk-app.nix).mkApp args {
  path = "graphical.editors.marktext";
  option = {
    name = "marktext";
    default = false;
    description = "MarkText markdown editor";
    persistedDirectories = [ ];
  };
  home = { pkgs, ... }: {
    home.packages = with pkgs; [
      marktext
    ];
  };
}
