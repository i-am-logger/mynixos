# App Management check for the apps home-manager copies on macOS.
#
# Copying over a notarised app needs the terminal running the rebuild to hold
# App Management. This keeps a probe of that before anything is copied, so a
# terminal without it stops the switch with instructions and no half-updated apps.
#
# Imported only by platforms/darwin.nix.
{ activeUsers, config, lib, ... }:

{
  config.home-manager.users = lib.mapAttrs
    (_name: _userCfg:
      { config, lib, ... }:
      let
        cfg = config.targets.darwin.copyApps;
      in
      {
        # Off because a denied probe makes home-manager's check run `tccutil reset
        # SystemPolicyAppBundles`, which clears App Management for every app. That
        # includes apps holding a valid certificate-based grant, so one rebuild from
        # a terminal without the permission would take them all away.
        targets.darwin.copyApps.enableChecks = lib.mkDefault false;

        home.activation.checkAppManagement = lib.mkIf (cfg.enable && !cfg.enableChecks) (
          lib.hm.dag.entryBefore [ "copyApps" ] ''
            appManagementAllowed() {
              local appBundle
              for appBundle in '${cfg.directory}/'*.app; do
                if [[ -d "$appBundle" ]] && ! run /usr/bin/touch "$appBundle/.DS_Store" &> /dev/null; then
                  return 1
                fi
              done
            }

            # A link is left over from linkApps and is migrated by copyApps, which
            # needs no permission for it.
            if [[ ! -L '${cfg.directory}' ]] && ! appManagementAllowed; then
              # macOS holds whatever sits at the top of the process tree responsible.
              topPid=$$
              while parentPid=$(/bin/ps -o ppid= -p "$topPid") && (( parentPid > 1 )); do
                topPid=$parentPid
              done
              errorEcho "App Management is not allowed for this rebuild; no apps were changed."
              errorEcho "Most likely responsible: $(/bin/ps -o comm= -p "$topPid")"
              errorEcho "Turn it on in System Settings > Privacy & Security > App Management, reopen that app, and rebuild."
              if [[ "$(/bin/launchctl managername)" != Aqua ]]; then
                errorEcho "Over SSH, rebuild from a graphical session instead, or allow Full Disk Access for remote users under General > Sharing > Remote Login."
              fi
              exit 1
            fi
          ''
        );
      })
    (activeUsers config.my.users);
}
