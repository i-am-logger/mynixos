args:

(import ../../../../../lib/mk-app.nix).mkApp args {
  path = "terminal.sysinfo.neofetch";
  home = { pkgs, ... }: {
    home.packages = with pkgs; [
      neofetch
      w3m
      imagemagick
    ];

    # NOTE: Config files from /etc/nixos/home/cli/neofetch/config/ need manual migration
    # Copy them to a suitable location if customization is needed
    # xdg.configFile."neofetch/" = {
    #   source = ./config;
    #   recursive = true;
    # };
  };
}
