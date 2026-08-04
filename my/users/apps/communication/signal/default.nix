args:

(import ../../../../../lib/mk-app.nix).mkApp args {
  path = "communication.messaging.signal";
  option = {
    name = "signal";
    default = false;
    description = "Signal Desktop messenger";
    persistedDirectories = [ ];
  };
  home = { pkgs, ... }: {
    home.packages = [
      # Wrapped, not bare: Electron otherwise probes a Secret Service keyring at
      # startup and stalls on hosts where none is running. This wrapper came from
      # my/users/webapps, which used to install Signal itself.
      (pkgs.symlinkJoin {
        name = "signal-desktop-wrapped";
        paths = [ pkgs.signal-desktop ];
        nativeBuildInputs = [ pkgs.makeWrapper ];
        postBuild = ''
          wrapProgram $out/bin/signal-desktop \
            --add-flags "--password-store=basic"
        '';
      })
    ];
  };
}
