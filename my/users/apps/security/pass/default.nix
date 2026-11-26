args:

# pass, the standard unix password manager. Its store (~/.password-store) is
# GPG-encrypted; the YubiKey module writes the store's .gpg-id for users with
# keys, which is all the coupling there is.
(import ../../../../../lib/mk-app.nix).mkApp args {
  path = "security.passwords.pass";
  option = {
    name = "pass";
    default = false;
    description = "pass (password-store), the GPG-backed password manager";
  };
  home = { pkgs, ... }: {
    home.packages = [ pkgs.pass ];
  };
}
