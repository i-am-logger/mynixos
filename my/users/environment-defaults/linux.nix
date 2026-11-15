# The default terminal for apps that ask for one, on Linux.
#
# A .desktop entry with Terminal=true has no terminal of its own: GLib and
# the launchers that follow the Default Terminal Execution Specification run
# it through xdg-terminal-exec, which reads ~/.config/xdg-terminals.list. That
# list names the TERMINAL selector's desktop entry, so $TERMINAL and those
# apps agree. How the command is passed comes from the entry's
# X-TerminalArgExec (baud's: `-e`).
#
# Imported only by platforms/linux.nix: the specification is freedesktop's.
{ activeUsers, config, lib, ... }:

with lib;

let
  # Desktop file IDs, which are the app ids, not the package names.
  desktopId = pname:
    {
      baud = "org.baud.terminal.desktop";
      wezterm = "org.wezfurlong.wezterm.desktop";
      kitty = "kitty.desktop";
      alacritty = "Alacritty.desktop";
      ghostty = "com.mitchellh.ghostty.desktop";
    }.${pname} or "${pname}.desktop";
in
{
  config.home-manager.users = mapAttrs
    (_name: userCfg:
      let terminal = userCfg.environment.TERMINAL;
      in mkIf (terminal != null && terminal.enable) {
        xdg.terminal-exec = {
          enable = true;
          settings.default = [ (desktopId (terminal.package.pname or "terminal")) ];
        };
      })
    (activeUsers config.my.users);
}
