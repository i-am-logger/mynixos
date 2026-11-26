args:

# pass, the standard unix password manager, with OTP codes (pass-otp) and the
# browserpass native host. Its store (~/.password-store) is GPG-encrypted; the
# YubiKey module writes the store's .gpg-id for users with keys, which is all
# the coupling there is.
(import ../../../../../lib/mk-app.nix).mkApp args {
  path = "security.passwords.pass";
  option = {
    name = "pass";
    default = false;
    description = "pass (password-store), the GPG-backed password manager";
    persistedDirectories = [ ".password-store" ];
  };
  home = { pkgs, ... }: {
    programs.password-store = {
      enable = true;
      package = pkgs.pass.withExtensions (exts: [ exts.pass-otp ]);
      settings = {
        PASSWORD_STORE_DIR = "$HOME/.password-store";
        PASSWORD_STORE_CLIP_TIME = "45";
      };
    };

    # The native host for the browserpass extension.
    programs.browserpass = {
      enable = true;
      browsers = [ "firefox" "chrome" "chromium" "brave" ];
    };
  };
}
