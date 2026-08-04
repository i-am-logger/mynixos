# Zellij terminal multiplexer.
#
# Gated on `terminal.multiplexer == "zellij"`, the same selector tmux uses. There
# is deliberately no apps.terminal.multiplexers.zellij option: a second on/off
# switch beside the selector is a second way to say one thing, and only one of
# them gets read -- which is exactly what happened here. The option existed,
# defaulted false, nothing ever set it, so every setting below was discarded and
# the multiplexer ran stock.
{ activeUsers, config, lib, ... }:

with lib;

let
  isZellij = userCfg: (userCfg.terminal.multiplexer or null) == "zellij";
in
{
  config = {

    home-manager.users = mapAttrs
      (_name: userCfg:
        mkIf (isZellij userCfg) {
          programs.zellij = {
            enable = true;

            # Both off on purpose: the shell integrations auto-START zellij from
            # the rc file, turning every interactive shell into a session.
            enableFishIntegration = false;
            enableBashIntegration = false;

            settings = {
              mouse_mode = true;
              copy_on_select = true;
              scrollback_editor = "hx";
              default_layout = "compact";

              ui = {
                pane_frames = {
                  hide_session_name = false;
                };
              };
            };
          };
        })
      (activeUsers config.my.users);
  };
}
