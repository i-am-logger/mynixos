args:

# gopass, a pass-compatible password manager with team stores and git sync.
(import ../../../../../lib/mk-app.nix).mkApp args {
  path = "security.passwords.gopass";
  option = {
    name = "gopass";
    default = false;
    description = "gopass, a pass-compatible password manager";
  };
  home = { pkgs, ... }: {
    home.packages = [ pkgs.gopass ];
  };
}
