args:

(import ../../../../../lib/mk-app.nix).mkApp args {
  # feh is an X11 image viewer, so it belongs to the graphical category — which is
  # where my/users/graphical/mynixos.nix enables it.
  path = "graphical.viewers.feh";
  option = {
    name = "feh";
    default = false;
    description = "feh image viewer";
  };
  # home-manager's programs.feh installs cfg.package itself, so listing feh in
  # home.packages as well puts it in the profile twice.
  home = { lib, ... }: {
    programs.feh.enable = lib.mkDefault true;
  };
}
