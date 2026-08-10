{ activeUsers, config, lib, pkgs, ... }:

with lib;

let
  # Check if ANY user has terminal enabled
  anyUserTerminal = any (u: u.terminal.enable or false) (attrValues config.my.users);
in
{
  config = mkIf anyUserTerminal {
    # Per-user home-manager configuration
    home-manager.users = mapAttrs
      (_name: userCfg:
        let
          termCfg = userCfg.terminal or { };
        in
        mkIf (termCfg.enable or false) {
          # zellij and tmux own their own enablement, keyed off the same
          # `multiplexer` selector (my/users/apps/multiplexers/*). screen has no
          # home-manager module, so it is just a package.
          home.packages = with pkgs;
            (optional (termCfg.multiplexer == "screen") screen);

          # Aliases, defined once for every shell. home.shellAliases is
          # home-manager's shell-agnostic option and fans out to bash, zsh and
          # fish alike, so they are available whichever shell you are in.
          #
          # ls/ll/la/lt/lla/llt are deliberately ABSENT: home-manager's
          # programs.lsd module already defines those six per shell, pointing at
          # an absolute store path. Redefining them here would collide, since
          # home.shellAliases lands in each shell at normal priority -- even
          # mkForce would not win.
          home.shellAliases = mkMerge [
            {
              ".." = "cd ..";
              "..." = "cd ../..";
              c = "clear";

              g = "git";
              gs = "git status -sb";
              gd = "git diff";
              gl = "git log --oneline --graph --decorate -20";
              gp = "git push";
              gco = "git checkout";

              # `cat` is deliberately NOT aliased to bat: its paging and
              # decorations break pipelines and heredocs in surprising ways.
              b = "bat";
              bp = "bat --plain";

              btm = "btop";
              zj = "zellij";
              hr = "herdr";
              cvp = "cava-peaks";
              t = "tree -C";

              # No command substitution, so portable as-is. The fish module
              # keeps the eff/cdf variants that need fish's `(...)`.
              ff = "fd --type file --color always | fzf --ansi";
              ffd = "fd --type directory --color always | fzf --ansi";
              cf = "find . -type f | wc -l";

              lsize = "lsd -l --total-size --sizesort";
              lls = "command ls"; # the real coreutils ls, when a script needs it
            }

            (mkIf pkgs.stdenv.hostPlatform.isDarwin {
              # caffeinate ships with macOS. `nosleep <cmd>` holds the machine
              # awake for exactly as long as that command runs.
              awake = "caffeinate -di";
              nosleep = "caffeinate -i";
            })

            (mkIf pkgs.stdenv.hostPlatform.isLinux {
              f = "free -h"; # no `free` on darwin
            })
          ];
        })
      (activeUsers config.my.users);
  };
}
