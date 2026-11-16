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
args:

(import ../../../../../lib/mk-app.nix).mkApp args {
  path = "ai.tools.claude-code";
  home = { cfg, pkgs, lib, ... }: lib.mkIf cfg.fleetWake.enable {
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
  };
}
