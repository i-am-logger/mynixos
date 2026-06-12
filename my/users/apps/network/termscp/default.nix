args:

(import ../../../../../lib/mk-app.nix).mkApp args {
  path = "terminal.network.termscp";
  home = { pkgs, ... }: {
    home.packages = with pkgs; [
      termscp
    ];
  };
}
