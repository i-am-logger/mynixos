{ config, lib, pkgs, ... }:

with lib;

{
  config = {
    home-manager.users = mapAttrs
      (name: userCfg:
        let
          browser = userCfg.environment.BROWSER;
          hasBrave = browser != null && browser.enable && browser.package.pname or "" == "brave";
        in
        mkIf hasBrave {
          # Wrap Brave to use gopass via secret service and GPG agent
          home.packages =
            let
              brave-with-gopass = pkgs.symlinkJoin {
                name = "brave-with-gopass";
                paths = [ pkgs.brave ];
                nativeBuildInputs = [ pkgs.makeWrapper ];
                postBuild = ''
                  wrapProgram $out/bin/brave \
                    --add-flags "--password-store=basic" \
                    --add-flags "--disable-password-manager" \
                    --add-flags "--enable-features=UseOzonePlatform" \
                    --add-flags "--ozone-platform=wayland" \
                    --set GNOME_KEYRING_CONTROL "" \
                    --set DISABLE_GNOME_KEYRING "1" \
                    --set SSH_AUTH_SOCK "$(gpgconf --list-dirs agent-ssh-socket)"
                '';
              };
            in
            [
              brave-with-gopass
            ];

          # Configure XDG for Brave
          xdg.desktopEntries.brave-browser = {
            name = "Brave Browser";
            comment = "Brave browser";
            exec = "brave %U";
            icon = "brave-browser";
            categories = [ "Network" "WebBrowser" ];
            mimeType = [
              "text/html"
              "text/xml"
              "application/xhtml+xml"
              "x-scheme-handler/http"
              "x-scheme-handler/https"
            ];
          };
        }
      )
      config.my.users;
  };
}
