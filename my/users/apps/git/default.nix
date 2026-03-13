{ config, lib, pkgs, ... }:

with lib;

{
  config = {
    home-manager.users = mapAttrs
      (_name: userCfg: {
        home.packages = with pkgs; [
          gh
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
            url."git@github.com:".insteadOf = "https://github.com/";
            core.editor = "hx";
          };

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
          };
        };
      })
      config.my.users;
  };
}
