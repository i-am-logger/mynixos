args:

(import ../../../../../lib/mk-app.nix).mkApp args {
  path = "graphical.network.rustdesk";
  option = {
    name = "RustDesk";
    default = false;
    description = "RustDesk remote desktop client";
    persistedDirectories = [ ".config/rustdesk" ];
  };
  # rustdesk links libsciter (its legacy Sciter-based UI toolkit dependency),
  # which nixpkgs marks unfree even though rustdesk itself is AGPL-3.0.
  unfree = [ "libsciter" ];
  home = { pkgs, ... }: {
    home.packages = with pkgs; [
      rustdesk
    ];
  };
}
