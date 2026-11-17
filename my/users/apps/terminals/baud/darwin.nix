# Signs the baud.app the Dock launches with a certificate the machine holds.
#
# baud's build signs ad hoc, which makes the bundle's designated requirement its
# cdhash, so macOS sees each build as a new app and its privacy grants do not
# carry over. Signed with a certificate, the requirement is the identifier and
# that certificate, the same for every build.
#
# Off unless `terminal.baud.signingIdentity` names a certificate, because the
# certificate belongs to one machine. Unset, baud.app stays ad hoc and macOS asks
# for its permissions again after each new build.
#
# This happens at activation because the key lives in the login keychain and must
# never reach the store or a build sandbox. copyApps puts the ad hoc build back
# on every activation, so this runs after it every time.
#
# An identity that is missing, or an activation that cannot use it, keeps the ad
# hoc app and a warning: a working terminal is worth more than a kept grant.
#
# Imported only by platforms/darwin.nix.
{ activeUsers, config, lib, ... }:

let
  bundleId = "dev.baud.terminal";

  isBaud = userCfg:
    let terminal = userCfg.environment.TERMINAL; in
    terminal != null && terminal.enable && (terminal.package.pname or "") == "baud";
in
{
  options.my.users = lib.mkOption {
    type = lib.types.attrsOf (lib.types.submodule {
      options.terminal = lib.mkOption {
        type = lib.types.submodule {
          options.baud.signingIdentity = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            example = "baud local signing";
            description = ''
              Name of a code-signing identity in the user's login keychain, used to
              sign baud.app at activation so its privacy grants survive a new build.
              Null leaves the app signed ad hoc.
            '';
          };
        };
      };
    });
  };

  config.home-manager.users = lib.mapAttrs
    (_name: userCfg:
      { lib, ... }:
      let
        identity = userCfg.terminal.baud.signingIdentity;
      in
      lib.mkIf (isBaud userCfg && identity != null) {
        home.activation.signBaud = lib.hm.dag.entryAfter [ "copyApps" ] ''
          baudApp="$HOME/Applications/Home Manager Apps/baud.app"
          baudIdentity=${lib.escapeShellArg identity}
          if [ -d "$baudApp" ]; then
            # Not grep -q: it would close the pipe early and pipefail would read
            # the signal as a missing identity.
            if /usr/bin/security find-identity -v -p codesigning | /usr/bin/grep -F "\"$baudIdentity\"" > /dev/null; then
              if ! run /usr/bin/codesign --force --sign "$baudIdentity" -i ${bundleId} "$baudApp"; then
                warnEcho "baud.app: could not sign with '$baudIdentity'; it stays ad hoc, and macOS will ask for its permissions again"
              fi
            else
              warnEcho "baud.app: no '$baudIdentity' identity in the keychain; it stays ad hoc, and macOS will ask for its permissions again"
            fi
          fi
        '';
      })
    (activeUsers config.my.users);
}
