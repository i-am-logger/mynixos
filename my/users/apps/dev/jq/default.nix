args:

(import ../../../../../lib/mk-app.nix).mkApp args {
  path = "dev.tools.jq";
  home = { pkgs, ... }: {
    home.packages = with pkgs; [
      jq
    ];
  };
}
