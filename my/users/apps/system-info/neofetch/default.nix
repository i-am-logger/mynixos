args:

(import ../../../../../lib/mk-app.nix).mkApp args {
  path = "terminal.sysinfo.neofetch";
  option = {
    name = "neofetch";
    default = false;
    description = "neofetch system info";
    persistedDirectories = [ ];
  };
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
