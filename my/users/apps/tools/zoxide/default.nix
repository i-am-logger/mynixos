args:

(import ../../../../../lib/mk-app.nix).mkApp args {
  path = "terminal.tools.zoxide";
  option = {
    name = "zoxide";
    default = true;
    description = "zoxide directory jumper";
  };
  # Integration is enabled for every shell rather than the login shell only: a
  # user can run any of them from a terminal, and the non-active ones are inert.
  home = { userCfg, ... }: {
    programs.zoxide = {
      enable = true;
      enableBashIntegration = true;
      enableZshIntegration = true;
      enableFishIntegration = userCfg.apps.terminal.shells.fish.enable;
    };
  };
}
