{ activeUsers, config, lib, pkgs, ... }:

with lib;

let
  # See ./options.nix. "ssh" rewrites forge URLs to their SSH form; "https"
  # leaves them alone and hands authentication to the forge CLI, which already
  # holds a token. The two are exclusive — a host does one or the other.
  transport = userCfg:
    if userCfg.apps.dev.tools.git.protocol == "ssh" then {
      # The same three hosts my/users/apps/ssh gives a Host block to. The https
      # branch covers only two: bitbucket has no packaged CLI holding a token,
      # so there is nothing to install as a helper -- see ./options.nix.
      #
      # One `url` attrset rather than three `url.<x>` lines: statix's
      # repeated_keys fires at three, and the pre-commit statix hook CHECKS
      # rather than fixes, so treefmt cannot paper over it.
      url = {
        "git@github.com:".insteadOf = "https://github.com/";
        "git@gitlab.com:".insteadOf = "https://gitlab.com/";
        "git@bitbucket.org:".insteadOf = "https://bitbucket.org/";
      };
    } else {
      # Bare names: gh/glab come from the dev workspace (apps.dev.tools.devenv
      # .workspace), not the host. Outside it git finds no helper and falls
      # back to its own prompt.
      credential."https://github.com".helper = "!gh auth git-credential";
      credential."https://gitlab.com".helper = "!glab auth git-credential";
    };
in
{
  config = {
    home-manager.users = mapAttrs
      (_name: userCfg: {
        # No gh, glab, lazygit, delta, git-lfs or jujutsu on the host: they are
        # development tools, carried by the dev workspace's devenv.
        programs.git = {
          enable = true;
          # The LFS filter, with git-lfs from the dev workspace: named bare and
          # not `required` (below), so a shell outside the workspace never fails
          # a checkout over a missing binary.
          lfs = {
            enable = true;
            package = null;
          };
          iniContent.filter.lfs.required = mkForce false;
          # Plain git: gitFull adds Subversion, send-email and Perl -- development
          # extras, not what the host needs to fetch and commit.
          package = pkgs.git;

          settings = {
            user = optionalAttrs (userCfg.fullName or null != null)
              {
                name = userCfg.fullName;
              } // optionalAttrs (userCfg.email or null != null) {
              inherit (userCfg) email;
            };

            # Opinionated aliases
            alias = {
              ci = "commit";
              ca = "commit --amend";
              co = "checkout";
              s = "status";
              l = "log --pretty=format:'%C(yellow)%h%Creset %C(cyan)%G?%Creset %C(white)%d%Creset %s %C(cyan)(%cr) %C(bold blue)<%an>%Creset'";
              graph = "log --decorate --oneline --graph";
              signature = "log --pretty=format:'⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯%n✧ %C(yellow)%h%Creset %(if:equals=G,%(G?))%C(green)✓%Creset%(else)%C(red)✉%Creset%(end) %C(white)%d%Creset %s%n⌘ %C(cyan)(%cr)%Creset %C(bold blue)<%an>%Creset%n⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯'";
            };

            # Opinionated config
            merge.conflictstyle = "zdiff3"; # show the common ancestor in conflicts
            diff.colorMoved = "default"; # distinguish moved lines from added/removed

            core.editor = "hx";

            # delta as the pager when the dev workspace puts it on PATH, less
            # otherwise -- never a pager command that fails outside ~/Code.
            # (HM's programs.delta would pin delta by store path onto the host.)
            core.pager = "command -v delta >/dev/null 2>&1 && exec delta || exec less";
            interactive.diffFilter = "command -v delta >/dev/null 2>&1 && exec delta --color-only || exec cat";
            delta = {
              features = "decorations";
              decorations = {
                commit-decoration-style = "bold yellow box ul";
                file-decoration-style = "none";
                file-style = "bold yellow ul";
              };
              whitespace-error-style = "22 reverse";
              navigate = true; # n / N jump between diff hunks
              line-numbers = true;
              side-by-side = true;
              hyperlinks = true;
              syntax-theme = "ansi"; # follows the terminal's light/dark
            };
          } // transport userCfg;

          # Opinionated ignores
          ignores = [
            "*.img"
            ".direnv"
            "result"
            # Claude Code's worktrees (<repo>/.claude/worktrees/<name>)
            ".claude/worktrees/"
          ];
        };
      })
      (activeUsers config.my.users);
  };
}
