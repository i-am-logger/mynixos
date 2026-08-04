{ lib, ... }@args:

(import ../../../../../lib/mk-app.nix).mkApp args {
  path = "terminal.shells.zsh";
  option = {
    name = "Zsh";
    default = false;
    description = "Zsh shell (the macOS default login shell)";
    persistedFiles = [ ".zsh_history" ];
    extraOptions = {
      historySize = lib.mkOption {
        type = lib.types.int;
        default = 50000;
        description = "Number of commands to keep in history";
      };
    };
  };
  home = { cfg, lib, ... }:
    {
      programs.zsh = {
        enable = true;

        autosuggestion.enable = lib.mkDefault true;
        syntaxHighlighting.enable = lib.mkDefault true;

        history = {
          size = lib.mkDefault cfg.historySize;
          save = lib.mkDefault cfg.historySize;
          ignoreDups = lib.mkDefault true;
          ignoreSpace = lib.mkDefault true;
          expireDuplicatesFirst = lib.mkDefault true;
          share = lib.mkDefault true;
        };

        # Aliases live in my/users/terminal/aliases.nix via home.shellAliases,
        # so they are identical in bash, zsh and fish rather than per-shell.

        sessionVariables = {
          # follows the terminal's own light/dark theme
          BAT_THEME = lib.mkDefault "ansi";
          # Colorized man pages
          MANPAGER = lib.mkDefault "sh -c 'sed -e s/.\\x08//g | bat -p -l man'";
          MANROFFOPT = lib.mkDefault "-c";
        };

        initContent = lib.mkOrder 1000 ''
          # yazi: `y` opens the file manager and cd's to wherever you quit
          y() {
            local tmp cwd
            tmp="$(mktemp -t yazi-cwd.XXXXXX)"
            yazi "$@" --cwd-file="$tmp"
            cwd="$(command cat -- "$tmp")"
            [ -n "$cwd" ] && [ "$cwd" != "$PWD" ] && builtin cd -- "$cwd"
            rm -f -- "$tmp"
          }
        '';
      };

      # `cat` is deliberately left as the real coreutils cat — bat's paging and
      # decorations break pipelines and heredocs in surprising ways. Use `b`.
    };
}
