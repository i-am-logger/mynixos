args:

(import ../../../../../lib/mk-app.nix).mkApp args {
  path = "finance.tracking.cointop";
  home = { pkgs, ... }: {
    home.packages = with pkgs; [
      cointop
    ];
  };
}
