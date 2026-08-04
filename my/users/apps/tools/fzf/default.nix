# fzf.
#
# Its own module rather than a clause inside the bash module, where it used to
# live: fzf is not a bash feature, and hanging it off bash meant a zsh login
# shell -- the default on darwin -- got no Ctrl-R, Ctrl-T or Alt-C.
args:

(import ../../../../../lib/mk-app.nix).mkApp args {
  path = "terminal.tools.fzf";
  option = {
    name = "fzf";
    default = true;
    description = "fzf fuzzy finder (Ctrl-R history, Ctrl-T files, Alt-C directories)";
  };
  home = { userCfg, ... }: {
    programs.fzf = {
      enable = true;
      enableBashIntegration = true;
      enableZshIntegration = true;
      enableFishIntegration = userCfg.apps.terminal.shells.fish.enable;

      # fd rather than find: it honours .gitignore and skips .git, which is what
      # makes the widgets usable in a repo.
      defaultCommand = "fd --type f --hidden --follow --exclude .git";
      defaultOptions = [ "--height 40%" "--layout=reverse" "--border" "--info=inline" ];
      fileWidgetCommand = "fd --type f --hidden --follow --exclude .git";
      fileWidgetOptions = [ "--preview 'bat -n --color=always --line-range :300 {}'" ];
      changeDirWidgetCommand = "fd --type d --hidden --follow --exclude .git";
      changeDirWidgetOptions = [ "--preview 'lsd --tree --depth 1 --color=always {}'" ];
    };
  };
}
