{ config, lib, pkgs, ... }:

with lib;

{
  config = {
    # Opinionated defaults are now in options/users/environment.nix
    # This module only implements the home-manager configuration

    home-manager.users = mapAttrs
      (name: userCfg:
        let
          env = userCfg.environment;

          # Get packages from environment
          preferredBrowser = if env.BROWSER != null then env.BROWSER.package else null;
          preferredTerminal = if env.TERMINAL != null then env.TERMINAL.package else null;
          preferredEditor = if env.EDITOR != null then env.EDITOR.package else null;
          preferredFileManager = if env.FILE_MANAGER != null then env.FILE_MANAGER.package else null;

          # Map package to desktop file name
          browserDesktopFile = pname:
            if pname == "brave" then "brave-browser.desktop"
            else if pname == "firefox" then "firefox.desktop"
            else if pname == "chromium" then "chromium-browser.desktop"
            else "${pname}.desktop";

          terminalDesktopFile = pname:
            if pname == "wezterm" then "org.wezfurlong.wezterm.desktop"
            else if pname == "kitty" then "kitty.desktop"
            else if pname == "alacritty" then "Alacritty.desktop"
            else "${pname}.desktop";

          editorDesktopFile = pname:
            if pname == "helix" then "helix.desktop"
            else if pname == "neovim" then "nvim.desktop"
            else "${pname}.desktop";

          fileManagerDesktopFile = pname:
            if pname == "yazi" then "yazi.desktop"
            else if pname == "ranger" then "ranger.desktop"
            else "${pname}.desktop";
        in
        mkMerge [
          # Set environment variables for preferred apps
          (mkIf (preferredBrowser != null) {
            home.sessionVariables.BROWSER = mkDefault "${preferredBrowser}/bin/${preferredBrowser.pname or "browser"}";
          })

          (mkIf (preferredTerminal != null) {
            home.sessionVariables.TERMINAL = mkDefault "${preferredTerminal}/bin/${preferredTerminal.pname or "terminal"}";
          })

          (mkIf (preferredEditor != null) {
            home.sessionVariables.EDITOR = mkDefault "${preferredEditor}/bin/${preferredEditor.pname or "editor"}";
            home.sessionVariables.VISUAL = mkDefault "${preferredEditor}/bin/${preferredEditor.pname or "editor"}";
          })

          # Set XDG MIME defaults for preferred apps
          (mkIf (preferredBrowser != null) {
            xdg.mimeApps.defaultApplications = {
              "text/html" = browserDesktopFile (preferredBrowser.pname or "browser");
              "x-scheme-handler/http" = browserDesktopFile (preferredBrowser.pname or "browser");
              "x-scheme-handler/https" = browserDesktopFile (preferredBrowser.pname or "browser");
              "x-scheme-handler/about" = browserDesktopFile (preferredBrowser.pname or "browser");
              "x-scheme-handler/unknown" = browserDesktopFile (preferredBrowser.pname or "browser");
            };
          })

          (mkIf (preferredEditor != null) {
            xdg.mimeApps.defaultApplications = {
              "text/plain" = editorDesktopFile (preferredEditor.pname or "editor");
              "text/markdown" = editorDesktopFile (preferredEditor.pname or "editor");
            };
          })
        ]
      )
      config.my.users;
  };
}
