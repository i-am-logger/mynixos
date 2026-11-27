# Linux implementation of claude-code's fleetWake (./options-linux.nix).
#
# fleetd's watch.sh blocks reading ~/.claude/fleet/events.fifo and rescans
# new/ on any line, and checks `systemctl --user is-active fleet-new.path`,
# so the unit names are part of that contract. These were transient units
# once, and went with the session that made them.
#
# A write to a FIFO blocks until a reader opens it. watch.sh holds it open
# read-write while it runs; when it does not run, `timeout` ends the write
# rather than leaving the service hanging. Mail is still in new/ for its next
# scan, so the lost wake costs nothing.
#
# accounts on impermanence: each ~/.claude-<name> is a bind mount from the
# persist root. home-manager-<user>.service requires and is ordered after
# those mounts (RequiresMountsFor), and claudeAccountsMounts runs before the
# links step and stops activation if a folder is not a mount point -- links
# made in the bare folder would vanish under the mount. Without persistence
# there is no mount to wait for, and no check.
args@{ config, lib, ... }:

let
  persisting = config.my.storage.impermanence.enable;
  # The account folders of a user that impermanence bind-mounts.
  mountedAccounts = userCfg:
    let cfg = userCfg.apps.ai.tools.claude-code; in
    lib.optionals (persisting && cfg.enable && cfg.persisted) cfg.accounts;
  app = (import ../../../../../lib/mk-app.nix).mkApp args {
    path = "ai.tools.claude-code";
    home = { cfg, userCfg, pkgs, lib, ... }: lib.mkMerge [
      (lib.mkIf (mountedAccounts userCfg != [ ]) {
        home.activation.claudeAccountsMounts = {
          after = [ "writeBoundary" ];
          before = [ "claudeAccounts" ];
          data = ''
            for _acct in ${lib.escapeShellArgs (mountedAccounts userCfg)}; do
              if ! ${lib.getExe' pkgs.util-linux "mountpoint"} -q "$HOME/.claude-$_acct"; then
                echo "ERROR: $HOME/.claude-$_acct is not a mount point -- its persist mount is missing; Claude account links not created" >&2
                exit 1
              fi
            done
          '';
        };
      })
      (lib.mkIf cfg.fleetWake.enable {
        systemd.user.paths.fleet-new = {
          Unit.Description = "Wake fleetd on new fleet mail";
          Path.PathChanged = "%h/.claude/fleet/new";
          Install.WantedBy = [ "default.target" ];
        };
        systemd.user.services.fleet-new = {
          Unit.Description = "Tell fleetd's watch.sh that fleet mail arrived";
          Service = {
            Type = "oneshot";
            ExecStart = "${pkgs.coreutils}/bin/timeout 2 ${pkgs.runtimeShell} -c 'echo new > %h/.claude/fleet/events.fifo'";
          };
        };
      })
    ];
  };
in
app // {
  config = lib.mkMerge [
    app.config
    {
      systemd.services = lib.mapAttrs'
        (name: userCfg: lib.nameValuePair "home-manager-${name}" {
          unitConfig.RequiresMountsFor =
            map (a: "${config.users.users.${name}.home}/.claude-${a}") (mountedAccounts userCfg);
        })
        (lib.filterAttrs (_: u: mountedAccounts u != [ ]) (import ../../../../../lib/active-users.nix lib config.my.users));
    }
  ];
}
