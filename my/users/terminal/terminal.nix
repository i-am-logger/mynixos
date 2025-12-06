{ config, lib, pkgs, ... }:

with lib;

let
  # Check if ANY user has terminal enabled
  anyUserTerminal = any (u: u.terminal.enable or false) (attrValues config.my.users);
in
{
  config = mkIf anyUserTerminal {
    # Per-user home-manager configuration
    home-manager.users = mapAttrs
      (name: userCfg:
        let
          termCfg = userCfg.terminal or { };
        in
        mkIf (termCfg.enable or false) (mkMerge [
          # Multiplexer configuration
          {
            programs.zellij.enable = (termCfg.multiplexer or "zellij") == "zellij";
            programs.tmux.enable = (termCfg.multiplexer or "zellij") == "tmux";
            # screen doesn't have home-manager module, add to packages if selected
            home.packages = with pkgs;
              (optional ((termCfg.multiplexer or "zellij") == "screen") screen);
          }

          # TUI Apps packages
          {
            home.packages = with pkgs;
              # File Managers
              (optional (termCfg.fileManagers.mc or false) mc) ++
              (optional (termCfg.fileManagers.yazi or true) yazi) ++

              # System Info
              (optional (termCfg.sysinfo.btop or false) btop) ++
              (optional (termCfg.sysinfo.htop or false) htop) ++
              (optional (termCfg.sysinfo.fastfetch or true) fastfetch) ++
              (optional (termCfg.sysinfo.neofetch or false) neofetch) ++

              # Viewers
              (optional (termCfg.viewers.bat or true) bat) ++

              # File Utils
              (optional (termCfg.fileUtils.lsd or true) lsd) ++

              # Network
              (optional (termCfg.network.termscp or false) termscp) ++

              # Fun/Eye Candy
              (optional (termCfg.fun.pipes or false) pipes) ++

              # Visualizers
              (optional (termCfg.visualizers.cava or false) cava);
          }
        ]))
      config.my.users;
  };
}
