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
      credential."https://github.com".helper = "!${pkgs.gh}/bin/gh auth git-credential";
      credential."https://gitlab.com".helper = "!${pkgs.glab}/bin/glab auth git-credential";
    };
in
{
  config = {
    home-manager.users = mapAttrs
      (_name: userCfg: {
        home.packages = with pkgs; [
          gh
          glab
          lazygit
        ];

        programs.git = {
          enable = true;
          lfs.enable = true;
          package = pkgs.gitFull;

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
          } // transport userCfg;

          # Opinionated ignores
          ignores = [
            "*.img"
            ".direnv"
            "result"
          ];
        };

        # Delta (diff viewer) - now separate from git
        programs.delta = {
          enable = true;
          enableGitIntegration = true;
          options = {
            decorations = {
              commit-decoration-style = "bold yellow box ul";
              file-decoration-style = "none";
              file-style = "bold yellow ul";
            };
            features = "decorations";
            whitespace-error-style = "22 reverse";

            navigate = true; # n / N jump between diff hunks
            line-numbers = true;
            side-by-side = true;
            hyperlinks = true;
            # mkDefault so a theming layer (vogix) can take it over.
            syntax-theme = lib.mkDefault "ansi"; # follows the terminal's light/dark
          };
        };
      })
      (activeUsers config.my.users);
  };
}
