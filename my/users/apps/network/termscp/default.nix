args:

(import ../../../../../lib/mk-app.nix).mkApp args {
  path = "terminal.network.termscp";
  option = {
    name = "termscp";
    default = false;
    description = "termscp TUI file transfer";
    persistedDirectories = [ ];
  };
  home = { pkgs, ... }: {
    home.packages = with pkgs; [
      termscp
    ];
  };
}
