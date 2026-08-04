args:

(import ../../../../../lib/mk-app.nix).mkApp args {
  path = "communication.messaging.slack";
  option = {
    name = "slack";
    default = false;
    description = "Slack communication tool";
    persistedDirectories = [ ];
  };
  unfree = [ "slack" ];
  home = { pkgs, ... }: {
    home.packages = [
      # Wrapped, not bare: Electron otherwise probes a Secret Service keyring at
      # startup and stalls on hosts where none is running. This wrapper came from
      # my/users/webapps, which used to install Slack itself.
      (pkgs.symlinkJoin {
        name = "slack-wrapped";
        paths = [ pkgs.slack ];
        nativeBuildInputs = [ pkgs.makeWrapper ];
        postBuild = ''
          wrapProgram $out/bin/slack \
            --add-flags "--password-store=basic"
        '';
      })
    ];
  };
}
