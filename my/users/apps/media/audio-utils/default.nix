args:

(import ../../../../../lib/mk-app.nix).mkApp args {
  path = "media.tools.audioUtils";
  option = {
    name = "Audio Utilities";
    default = false;
    description = "Audio utilities (pavucontrol, pamixer)";
    persistedDirectories = [ ];
  };
  home = { pkgs, ... }: {
    home.packages = with pkgs; [
      # Audio utilities
      pavucontrol
      pamixer
    ];
  };
}
