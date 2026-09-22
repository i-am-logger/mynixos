# Linux implementation of the per-user radicle node declared in ./default.nix.
#
# Three units, all gated on the user's `apps.dev.tools.radicle.node.enable` and
# all dormant until `rad auth` has created ~/.radicle/keys (rad auth owns key
# creation and refuses to adopt a pre-existing config.json, so declarative
# config must follow it, not precede it):
#
# 1. radicle-config-pin -- copies the store-rendered private-net config.json
#    over ~/.radicle/config.json on login. `rad auth` writes the PUBLIC
#    bootstrap seeds into preferredSeeds; this pin is what keeps a user
#    profile inside the private net. A copy, not a symlink: `rad config`
#    subcommands expect a writable file. (lib.hm.dag is unavailable through
#    mkApp's home function -- see my/hardware/security-keys/yubico/gpg.nix
#    for the same trade -- so this is a user service, not home.activation.)
#
# 2. radicle-node -- the daemon, outbound-only, run against the store config
#    directly (--config), so it is correct even before the pin has run. The
#    key is the user's own; `rad auth` protects it with a passphrase by
#    default, and a passphrase-protected key cannot start non-interactively,
#    so docs/radicle.md recommends passphrase-less user keys on this fleet
#    (disks are encrypted; the machine key in my.infra.radicle makes the same
#    call).
#
# 3. radicle-node.socket -- the node's control socket, bound by systemd rather
#    than by the node. ~/.radicle persists across boots, so a socket file left
#    by a node that died uncleanly survives the reboot, and the node refuses to
#    start while bind() finds its path taken ("another node appears to be
#    running"). systemd replaces a stale socket file when it binds; the node
#    takes the listener over as the fd named "control" (radicle-node's
#    `systemd` feature, on by default) and never binds the path itself.
args:

(import ../../../../../lib/mk-app.nix).mkApp args {
  path = "dev.tools.radicle";
  home = { cfg, name, pkgs, lib, ... }:
    let
      nodeConfig = builtins.toJSON {
        preferredSeeds = [ ];
        node = {
          alias = if cfg.node.alias != null then cfg.node.alias else name;
          listen = [ ];
          peers.type = "static";
          inherit (cfg.node) connect;
          externalAddresses = [ ];
          network = "main";
          seedingPolicy.default = "block";
        };
      };
      configFile = pkgs.writeText "radicle-user-config.json" nodeConfig;
    in
    lib.mkIf cfg.node.enable {
      systemd.user.services = {
        radicle-config-pin = {
          Unit = {
            Description = "Pin ~/.radicle/config.json to the private-net shape";
            ConditionPathExists = "%h/.radicle/keys/radicle.pub";
          };
          Service = {
            Type = "oneshot";
            ExecStart = "${pkgs.coreutils}/bin/install -m 600 ${configFile} %h/.radicle/config.json";
          };
          Install.WantedBy = [ "default.target" ];
        };

        radicle-node = {
          Unit = {
            Description = "Radicle node (user, outbound-only)";
            After = [ "radicle-config-pin.service" "radicle-node.socket" ];
            Wants = [ "radicle-config-pin.service" ];
            Requires = [ "radicle-node.socket" ];
            ConditionPathExists = "%h/.radicle/keys/radicle";
          };
          Service = {
            ExecStart = "${pkgs.radicle-node}/bin/radicle-node --config ${configFile}";
            Restart = "on-failure";
            RestartSec = "30";
            Environment = [ "RAD_HOME=%h/.radicle" ];
          };
          Install.WantedBy = [ "default.target" ];
        };
      };

      systemd.user.sockets.radicle-node = {
        Unit = {
          Description = "Radicle node control socket";
          # The node's own condition: a socket for a node that cannot start
          # would activate it on every `rad` connection until systemd's trigger
          # rate limit failed the socket.
          ConditionPathExists = "%h/.radicle/keys/radicle";
        };
        Socket = {
          ListenStream = "%h/.radicle/node/control.sock";
          FileDescriptorName = "control";
          SocketMode = "0600";
        };
        Install.WantedBy = [ "sockets.target" ];
      };
    };
}
