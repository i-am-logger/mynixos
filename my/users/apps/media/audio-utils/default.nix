args:

(import ../../../../../lib/mk-app.nix).mkApp args {
  path = "media.tools.audioUtils";
  home = { pkgs, ... }: {
    home.packages = with pkgs; [
      # Audio utilities
      pavucontrol
      pamixer
    ];
  };
}
