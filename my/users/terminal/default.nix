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
          # Multiplexer configuration
          programs.zellij.enable = mkDefault ((termCfg.multiplexer or "zellij") == "zellij");
          # screen doesn't have home-manager module, add to packages if selected
          home.packages = with pkgs;
            (optional ((termCfg.multiplexer or "zellij") == "screen") screen);
        })
      (activeUsers config.my.users);
  };
}
