args:

(import ../../../../../lib/mk-app.nix).mkApp args {
  path = "dev.tools.direnv";
  home = _: {
    programs.direnv = {
      enable = true;
      nix-direnv.enable = true;
    };
  };
}
