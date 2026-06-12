args:

(import ../../../../../lib/mk-app.nix).mkApp args {
  path = "terminal.multiplexers.zellij";
  home = _: {
    programs.zellij = {
      enable = true;
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
  };
}
