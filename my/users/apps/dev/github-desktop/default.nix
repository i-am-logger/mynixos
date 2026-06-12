args:

(import ../../../../../lib/mk-app.nix).mkApp args {
  path = "dev.tools.githubDesktop";
  home = { pkgs, ... }: {
    home.packages = with pkgs; [
      github-desktop
    ];
  };
}
