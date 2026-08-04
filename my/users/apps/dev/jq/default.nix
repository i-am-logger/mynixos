args:

(import ../../../../../lib/mk-app.nix).mkApp args {
  path = "dev.tools.jq";
  option = {
    name = "jq";
    default = false;
    description = "jq JSON processor";
    persistedDirectories = [ ];
  };
  home = { pkgs, ... }: {
    home.packages = with pkgs; [
      jq
    ];
  };
}
