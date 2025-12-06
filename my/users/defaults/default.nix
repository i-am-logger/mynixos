{ config, lib, pkgs, ... }:

with lib;

let
  # Helper to normalize program options (string or submodule)
  normalizeProgram = value:
    if isString value then
      { program = value; settings = {}; package = null; }
    else
      value;

  # Type for program options with string coercion
  programOption = programName: validPrograms: mkOption {
    type = types.nullOr (types.either
      (types.enum validPrograms)
      (types.submodule {
        options = {
          program = mkOption {
            type = types.enum validPrograms;
            description = "Program name";
          };
          settings = mkOption {
            type = types.attrs;
            default = {};
            description = "Program-specific settings to merge with programs.<name>";
          };
          package = mkOption {
            type = types.nullOr types.package;
            default = null;
            description = "Override the package used for this program";
          };
        };
      })
    );
    default = null;
    description = "Choose ${programName}";
  };

  # Tier 1 programs (highest priority, most common)
  tier1Programs = {
    browsers = [ "firefox" "brave" "chromium" "qutebrowser" ];
    terminals = [ "kitty" "wezterm" "alacritty" "ghostty" "foot" ];
    editors = [ "neovim" "helix" "emacs" "vim" ];
    launchers = [ "rofi" "wofi" "fuzzel" "tofi" ];
    fileManagers = [ "yazi" "ranger" "lf" "nnn" ];
  };
in
{
  options.my.users = mkOption {
    type = types.attrsOf (types.submodule {
      options.defaults = {
        # Browser selection
        browser = programOption "browser" tier1Programs.browsers;

        # Terminal selection
        terminal = programOption "terminal" tier1Programs.terminals;

        # Editor selection
        editor = programOption "editor" tier1Programs.editors;

        # Launcher selection
        launcher = programOption "launcher" tier1Programs.launchers;

        # File manager selection
        fileManager = programOption "file manager" tier1Programs.fileManagers;

        # Window manager (for future expansion)
        windowManager = mkOption {
          type = types.nullOr (types.enum [ "hyprland" "gnome" "kde" "sway" ]);
          default = null;
          description = "Override default window manager (mynixos default: hyprland)";
        };
      };
    });
  };

  config = {
    # Enable home-manager programs.* based on user defaults
    home-manager.users = mapAttrs (userName: userCfg:
      let
        defaults = userCfg.defaults or {};

        # Normalize all program defaults
        browser = if defaults.browser != null then normalizeProgram defaults.browser else null;
        terminal = if defaults.terminal != null then normalizeProgram defaults.terminal else null;
        editor = if defaults.editor != null then normalizeProgram defaults.editor else null;
        launcher = if defaults.launcher != null then normalizeProgram defaults.launcher else null;
        fileManager = if defaults.fileManager != null then normalizeProgram defaults.fileManager else null;
      in
      mkMerge [
        # Browser programs
        (mkIf (browser != null && browser.program == "firefox") {
          programs.firefox = mkMerge [
            {
              enable = true;
              package = if browser.package != null then browser.package else pkgs.firefox;
            }
            browser.settings
          ];
        })

        (mkIf (browser != null && browser.program == "brave") {
          programs.brave = mkMerge [
            {
              enable = true;
              package = if browser.package != null then browser.package else pkgs.brave;
            }
            browser.settings
          ];
        })

        (mkIf (browser != null && browser.program == "chromium") {
          programs.chromium = mkMerge [
            {
              enable = true;
              package = if browser.package != null then browser.package else pkgs.chromium;
            }
            browser.settings
          ];
        })

        (mkIf (browser != null && browser.program == "qutebrowser") {
          programs.qutebrowser = mkMerge [
            {
              enable = true;
              package = if browser.package != null then browser.package else pkgs.qutebrowser;
            }
            browser.settings
          ];
        })

        # Terminal programs
        (mkIf (terminal != null && terminal.program == "kitty") {
          programs.kitty = mkMerge [
            {
              enable = true;
              package = if terminal.package != null then terminal.package else pkgs.kitty;
            }
            terminal.settings
          ];
        })

        (mkIf (terminal != null && terminal.program == "wezterm") {
          programs.wezterm = mkMerge [
            {
              enable = true;
              package = if terminal.package != null then terminal.package else pkgs.wezterm;
            }
            terminal.settings
          ];
        })

        (mkIf (terminal != null && terminal.program == "alacritty") {
          programs.alacritty = mkMerge [
            {
              enable = true;
              package = if terminal.package != null then terminal.package else pkgs.alacritty;
            }
            terminal.settings
          ];
        })

        (mkIf (terminal != null && terminal.program == "ghostty") {
          programs.ghostty = mkMerge [
            {
              enable = true;
              package = if terminal.package != null then terminal.package else pkgs.ghostty;
            }
            terminal.settings
          ];
        })

        (mkIf (terminal != null && terminal.program == "foot") {
          programs.foot = mkMerge [
            {
              enable = true;
              package = if terminal.package != null then terminal.package else pkgs.foot;
            }
            terminal.settings
          ];
        })

        # Editor programs
        (mkIf (editor != null && editor.program == "neovim") {
          programs.neovim = mkMerge [
            {
              enable = true;
              package = if editor.package != null then editor.package else pkgs.neovim;
            }
            editor.settings
          ];
        })

        (mkIf (editor != null && editor.program == "helix") {
          programs.helix = mkMerge [
            {
              enable = true;
              package = if editor.package != null then editor.package else pkgs.helix;
            }
            editor.settings
          ];
        })

        (mkIf (editor != null && editor.program == "emacs") {
          programs.emacs = mkMerge [
            {
              enable = true;
              package = if editor.package != null then editor.package else pkgs.emacs;
            }
            editor.settings
          ];
        })

        (mkIf (editor != null && editor.program == "vim") {
          programs.vim = mkMerge [
            {
              enable = true;
              package = if editor.package != null then editor.package else pkgs.vim;
            }
            editor.settings
          ];
        })

        # Launcher programs
        (mkIf (launcher != null && launcher.program == "rofi") {
          programs.rofi = mkMerge [
            {
              enable = true;
              package = if launcher.package != null then launcher.package else pkgs.rofi;
            }
            launcher.settings
          ];
        })

        (mkIf (launcher != null && launcher.program == "wofi") {
          programs.wofi = mkMerge [
            {
              enable = true;
              package = if launcher.package != null then launcher.package else pkgs.wofi;
            }
            launcher.settings
          ];
        })

        (mkIf (launcher != null && launcher.program == "fuzzel") {
          programs.fuzzel = mkMerge [
            {
              enable = true;
              package = if launcher.package != null then launcher.package else pkgs.fuzzel;
            }
            launcher.settings
          ];
        })

        (mkIf (launcher != null && launcher.program == "tofi") {
          programs.tofi = mkMerge [
            {
              enable = true;
              package = if launcher.package != null then launcher.package else pkgs.tofi;
            }
            launcher.settings
          ];
        })

        # File manager programs
        (mkIf (fileManager != null && fileManager.program == "yazi") {
          programs.yazi = mkMerge [
            {
              enable = true;
              package = if fileManager.package != null then fileManager.package else pkgs.yazi;
            }
            fileManager.settings
          ];
        })

        (mkIf (fileManager != null && fileManager.program == "ranger") {
          # Note: ranger doesn't have a home-manager module yet, install as package
          home.packages = [ (if fileManager.package != null then fileManager.package else pkgs.ranger) ];
        })

        (mkIf (fileManager != null && fileManager.program == "lf") {
          # Note: lf doesn't have a home-manager module yet, install as package
          home.packages = [ (if fileManager.package != null then fileManager.package else pkgs.lf) ];
        })

        (mkIf (fileManager != null && fileManager.program == "nnn") {
          # Note: nnn doesn't have a home-manager module yet, install as package
          home.packages = [ (if fileManager.package != null then fileManager.package else pkgs.nnn) ];
        })
      ]
    ) config.my.users;
  };
}
