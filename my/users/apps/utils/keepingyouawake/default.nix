{ lib, ... }@args:

(import ../../../../../lib/mk-app.nix).mkApp args {
  path = "graphical.utils.keepingyouawake";
  option = {
    name = "KeepingYouAwake";
    default = false;
    description = "Menu-bar sleep-prevention toggle";
    extraOptions = {
      autoStart = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = ''
          Launch at login via a launchd user agent. macOS Login Items are not
          declaratively manageable, so a launchd agent is the equivalent. A
          menu-bar app that does not start at login is of little use, hence the
          default.
        '';
      };
      activateOnLaunch = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          Start actively preventing sleep as soon as it launches, rather than
          starting idle.
        '';
      };
    };
  };
  # Drives macOS IOKit power assertions, so it exists only on darwin. That is
  # expressed by platforms/darwin.nix being the only file that imports this one --
  # no isDarwin test, because there is nowhere else for it to run.
  home = { cfg, lib, pkgs, ... }:
    let
      kya = pkgs.callPackage ../../../../../packages/keepingyouawake { };
    in
    {
      home.packages = [ kya ];

      # macOS Login Items cannot be set declaratively (they live in a private
      # SMAppService database), so a launchd user agent is how a login-start is
      # expressed. `-a` opens the bundle rather than exec'ing the binary, so the
      # app registers with the Dock/menu bar the way a normal launch does.
      launchd.agents.keepingyouawake = lib.mkIf cfg.autoStart {
        enable = true;
        config = {
          Label = "info.marcel-dierkes.KeepingYouAwake";
          ProgramArguments = [
            "/usr/bin/open"
            "-a"
            "${kya}/Applications/KeepingYouAwake.app"
          ];
          RunAtLoad = true;
          # One-shot: `open` returns immediately once the app is running, so
          # KeepAlive would relaunch it in a loop.
          KeepAlive = false;
        };
      };

      # Its own preference domain. Written through home-manager rather than
      # nix-darwin's system.defaults because this is per-user state.
      targets.darwin.defaults."info.marcel-dierkes.KeepingYouAwake" =
        lib.mkIf cfg.activateOnLaunch {
          KYAActivateOnLaunch = true;
        };
    };
}
