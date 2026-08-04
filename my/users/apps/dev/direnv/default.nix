args:

(import ../../../../../lib/mk-app.nix).mkApp args {
  path = "dev.tools.direnv";
  option = {
    name = "direnv";
    default = false;
    description = "direnv environment manager";
    persistedDirectories = [
      ".direnv"
      ".local/share/direnv"
    ];
  };
  home = _: {
    programs.direnv = {
      enable = true;
      nix-direnv.enable = true;
    };
  };
}
