{ config, lib, pkgs, ... }:

with lib;

{
  config = {
    home-manager.users = mapAttrs
      (name: userCfg:
        mkIf userCfg.apps.shells.fish {
      home.packages = with pkgs; [
        # thefuck has been removed, using pay-respects instead
        grc
        fzf
        fd
      ];

      # programs.kitty.shellIntegration.enableFishIntegration = true;
      services.gpg-agent.enableFishIntegration = true;

      programs.fish = {
        enable = true;

        shellAliases = {
          # Navigation
          ".." = "cd ..";
          c = "clear";

          # File finding utilities
          ff = "fd --type file --color always | fzf --ansi"; # find file
          ffd = "fd --type directory --color always | fzf --ansi"; # find directory
          eff = "$EDITOR (ff)"; # edit found file
          cdf = "cd (ffd)"; # cd to found directory
          cf = "find . -type f | wc -l"; # count files recursively

          # System info
          f = "free -h"; # memory usage
          g = "git";
          t = "tree -C --gitignore";

          # Utilities
          mnt = "mount | awk -F' ' '{ printf \"%s\t%s\n\",\$1,\$3; }' | column -t | egrep ^/dev/ | sort";
          cpv = "rsync -ah --info=progress2";
          weather = "curl wttr.in";

          # Add your personal aliases in your system-specific configuration
          # Example: y = "yazi"; h = "hx"; etc.
        };

        interactiveShellInit = ''
          set fish_greeting # Disable greeting
          function cl --argument dir
            if [ "dir" = "" ]
              builtin cd $HOME
            else
              builtin cd $dir
            end
            ls -a
          end

          function cdr
            # Check if current directory is within a git repository
            if not git rev-parse --is-inside-work-tree >/dev/null 2>&1
              echo "Error: Not in a git repository" >&2
              return 1
            end

            # Get the root directory of the git repository and change to it
            cd (git rev-parse --show-toplevel)
          end

          set fish_cursor_default block
        '';

        plugins = [
          {
            name = "puffer";
            src = pkgs.fishPlugins.puffer.src;
          }
          {
            name = "fzf-fish";
            src = pkgs.fishPlugins.fzf-fish.src;
          }
          # {
          #   name = "forgit";
          #   src = pkgs.fishPlugins.forgit.src;
          # }
          {
            name = "foreign-env";
            src = pkgs.fishPlugins.foreign-env.src;
          }
          {
            name = "grc";
            src = pkgs.fishPlugins.grc.src;
          }
          {
            name = "colored-man-pages";
            src = pkgs.fishPlugins.colored-man-pages.src;
          }
          {
            name = "z";
            src = pkgs.fetchFromGitHub {
              owner = "jethrokuan";
              repo = "z";
              rev = "e0e1b9dfdba362f8ab1ae8c1afc7ccf62b89f7eb";
              sha256 = "0dbnir6jbwjpjalz14snzd3cgdysgcs3raznsijd6savad3qhijc";
            };
          }
        ];
      };
        }
      )
      config.my.users;
  };
}
