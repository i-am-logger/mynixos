{ activeUsers, config, lib, ... }:

with lib;

# Locker domain app: when the user's environment.locker is hyprlock, install +
# manage it via home-manager. Mirrors my/users/apps/launchers/walker. vogix's
# Super+Shift+X bind consumes $LOCKER (set in environment-defaults), so swapping
# the locker is a one-line change to environment.locker.package.
{
  config = {
    home-manager.users = mapAttrs
      (_name: userCfg:
        let
          inherit (userCfg.environment) locker;
          hasHyprlock = locker != null && locker.enable && locker.package.pname or "" == "hyprlock";
        in
        mkIf hasHyprlock {
          programs.hyprlock.enable = true;
        }
      )
      (activeUsers config.my.users);
  };
}
