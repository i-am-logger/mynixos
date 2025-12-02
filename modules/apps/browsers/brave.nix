{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.my.apps.browsers.brave;
in
{

  config = mkIf cfg {
    home-manager.users = mapAttrs (name: userCfg: {
      # Wrap Brave to use gopass via secret service and GPG agent
      home.packages = let
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
              --add-flags "--force-device-scale-factor=1.25" \
              --set GNOME_KEYRING_CONTROL "" \
              --set DISABLE_GNOME_KEYRING "1" \
              --set SSH_AUTH_SOCK "$(gpgconf --list-dirs agent-ssh-socket)"
          '';
        };
      in [
        brave-with-gopass
      ];

      # Copy the SkySpy wallpaper to a location Brave can access
      # Note: You may need to adjust the source path to match your theme location
      # home.file.".local/share/skyspy/skyspy-wallpaper.png" = {
      #   source = ../../../Themes/Wallpapers/skyspy-wallpaper-2560x1600.png;
      # };

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
    }) config.my.users;
  };
}
