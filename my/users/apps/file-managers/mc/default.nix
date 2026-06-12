args:

(import ../../../../../lib/mk-app.nix).mkApp args {
  path = "terminal.fileManagers.mc";
  home = { pkgs, ... }: {
    home.packages = with pkgs; [
      mc
    ];

    # Note: You'll need to copy the config files from /etc/nixos/home/cli/mc/config
    # to a suitable location in your mynixos repository and adjust the source path below
    # xdg.configFile."mc" = {
    #   source = ./config;  # Adjust path to your mc config location
    #   recursive = true;
    # };
  };
}
