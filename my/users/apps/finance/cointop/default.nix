args:

(import ../../../../../lib/mk-app.nix).mkApp args {
  path = "finance.tracking.cointop";
  option = {
    name = "cointop";
    default = false;
    description = "Cointop cryptocurrency tracker";
    persistedDirectories = [ ];
  };
  home = { pkgs, ... }: {
    home.packages = with pkgs; [
      cointop
    ];
  };
}
