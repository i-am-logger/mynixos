args:

(import ../../../../../lib/mk-app.nix).mkApp args {
  path = "dev.tools.githubDesktop";
  option = {
    name = "githubDesktop";
    default = false;
    description = "GitHub Desktop";
    persistedDirectories = [ ];
  };
  home = { pkgs, ... }: {
    home.packages = with pkgs; [
      github-desktop
    ];
  };
}
