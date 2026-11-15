{ activeUsers, config, lib, ... }:

with lib;

{
  config = {
    # Opinionated defaults are now in options/users/environment.nix
    # This module only implements the home-manager configuration

    # A selected terminal that is not installed is a Super+Return that opens
    # nothing, with no error anywhere. Refuse the configuration instead.
    assertions = mapAttrsToList
      (name: userCfg:
        let
          t = userCfg.environment.TERMINAL;
          installed = config.home-manager.users.${name}.home.packages;
        in
        {
          assertion = t == null || !t.enable
            || any (p: (p.outPath or null) == t.package.outPath) installed;
          message = "my.users.${name}.environment.TERMINAL selects ${t.package.pname or "a terminal"}, but it is not in ${name}'s packages: $TERMINAL and Super+Return would run a missing program.";
        })
      (activeUsers config.my.users);

    home-manager.users = mapAttrs
      (_name: userCfg:
        let
          env = userCfg.environment;

          # Get packages from environment
          preferredBrowser = if env.BROWSER != null then env.BROWSER.package else null;
          preferredTerminal = if env.TERMINAL != null then env.TERMINAL.package else null;
          preferredEditor = if env.EDITOR != null then env.EDITOR.package else null;
          preferredLauncher = if env.launcher != null then env.launcher.package else null;
          preferredLocker = if env.locker != null then env.locker.package else null;

          # Map package to desktop file name
          browserDesktopFile = pname:
            if pname == "brave" then "brave-browser.desktop"
            else if pname == "firefox" then "firefox.desktop"
            else if pname == "chromium" then "chromium-browser.desktop"
            else "${pname}.desktop";

          editorDesktopFile = pname:
            if pname == "helix" then "helix.desktop"
            else if pname == "neovim" then "nvim.desktop"
            else "${pname}.desktop";
        in
        mkMerge [
          # Set environment variables for preferred apps
          (mkIf (preferredBrowser != null) {
            home.sessionVariables.BROWSER = mkDefault "${preferredBrowser}/bin/${preferredBrowser.pname or "browser"}";
          })

          # The selector installs what it selects: $TERMINAL, Super+Return
          # and the launcher run it by name, so it must be on PATH whether or
          # not the terminal has a module of its own (wezterm does; baud's
          # config module installs nothing). The same package twice is one.
          (mkIf (preferredTerminal != null) {
            home.sessionVariables.TERMINAL = mkDefault "${preferredTerminal}/bin/${preferredTerminal.pname or "terminal"}";
            home.packages = [ preferredTerminal ];
          })

          (mkIf (preferredEditor != null) {
            home.sessionVariables.EDITOR = mkDefault "${preferredEditor}/bin/${preferredEditor.pname or "editor"}";
            home.sessionVariables.VISUAL = mkDefault "${preferredEditor}/bin/${preferredEditor.pname or "editor"}";
          })

          # $LAUNCHER / $LOCKER are mynixos's own (non-standard) conventions so
          # consumers — vogix's Super+Space / Super+Shift+X, the Hyprland binds —
          # use the chosen launcher/locker instead of hardcoding one. Appearance
          # lives in each tool's own config, so the command is just the binary.
          # lib.getExe, not "${pkg}/bin/${pkg.pname}": wrapper packages
          # (pkgs.vogix-lock is a writeShellApplication) carry mainProgram
          # but no pname, and the old pattern would resolve to bin/locker.
          (mkIf (preferredLauncher != null) {
            home.sessionVariables.LAUNCHER = mkDefault (lib.getExe preferredLauncher);
          })

          (mkIf (preferredLocker != null) {
            home.sessionVariables.LOCKER = mkDefault (lib.getExe preferredLocker);
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
      (activeUsers config.my.users);
  };
}
