args:

(import ../../../../../lib/mk-app.nix).mkApp args {
  path = "communication.messaging.element";
  option = {
    name = "element";
    default = false;
    description = "Element Matrix client";
    persistedDirectories = [ ".config/Element" ];
  };
  home = { pkgs, ... }: {
    home.packages = with pkgs; [
      element-desktop
    ];
  };
}
