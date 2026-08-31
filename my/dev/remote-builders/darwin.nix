# Accept remote nix builds -- the darwin (builder host) half of
# my.dev.builderHost. The Linux (client) half is ./default.nix.
#
# Three pieces make the Mac a builder:
#
# 1. A locked-down account. `restrict` strips forwarding/pty; the forced
#    command pins the session to `nix-daemon --stdio` by absolute path (which
#    is also exactly what an ssh-ng client runs), so PATH does not matter,
#    PermitUserEnvironment is unnecessary, and the key can do nothing else.
#    Keys land in /etc/ssh/authorized_keys.d/<user>, the path the sshd
#    hardening in my/network/openssh/darwin.nix already trusts.
#
# 2. Daemon trust. ssh-ng imports unsigned store paths, so the daemon must
#    list the account in trusted-users. nix-darwin cannot write nix.conf on
#    this fleet (nix.enable = false -- the installer owns nix), but the
#    installer's nix.conf `!include`s /etc/nix/nix.custom.conf, which
#    environment.etc CAN own. After the first activation the nix daemon needs
#    one manual kick: `sudo launchctl kickstart -k system/org.nixos.nix-daemon`.
#
# 3. Reachability policy is already handled: the pf ssh-firewall scopes sshd
#    to the tailscale address ranges, and sshd is pubkey-only.
{ config
, lib
, ...
}:

with lib;

let
  cfg = config.my.dev.builderHost;
in
{
  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = config.services.openssh.enable == true;
        message = "my.dev.builderHost requires services.openssh.enable = true (Remote Login is how builds arrive).";
      }
      {
        assertion = cfg.authorizedKey != "";
        message = ""
          + "my.dev.builderHost.authorizedKey is empty: the authorized_keys.d entry would be a "
          + "bare forced-command line, which sshd rejects as malformed -- Remote Login would keep "
          + "working but every remote build would fail with a confusing auth error.";
      }
    ];

    users.knownUsers = [ cfg.user ];
    users.users.${cfg.user} = {
      inherit (cfg) uid;
      description = "nix remote build account";
      home = "/var/empty";
      # The forced command supplies the only thing this account ever runs;
      # a real shell is still required for sshd to execute it.
      shell = "/bin/zsh";
      createHome = false;
    };

    environment.etc = {
      "ssh/authorized_keys.d/${cfg.user}".text =
        ''restrict,command="/nix/var/nix/profiles/default/bin/nix-daemon --stdio" ${cfg.authorizedKey}'' + "\n";

      "nix/nix.custom.conf".text = ''
        extra-trusted-users = ${cfg.user}
      '';
    };
  };
}
