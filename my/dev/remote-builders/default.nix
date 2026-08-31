# Remote nix builders -- the Linux (client) half of my.dev.remoteBuilders.
# The darwin (builder host) half is ./darwin.nix, imported only by
# platforms/darwin.nix.
#
# The nix daemon (root) does the dispatching, so the ssh key is root-owned
# and ordinary users -- including the radicle CI broker -- never touch it:
# they just run `nix build` and the daemon fans out.
#
# An unreachable builder is a LOUD failure, not a silent skip: for a system
# nothing local can build, nix fails after the connect timeout. ConnectTimeout
# is pinned low so an asleep laptop costs seconds, not the 2-minute default;
# policy about whether that failure is acceptable lives with the caller
# (radicle-ci-build's --policy flag, for CI).
{ config
, lib
, ...
}:

with lib;

let
  cfg = config.my.dev;
in
{
  config = mkIf (cfg.remoteBuilders != [ ]) {
    assertions = [
      {
        assertion = config.my.secrets.enable;
        message = "my.dev.remoteBuilders requires my.secrets.enable = true (the builder ssh key comes from sops).";
      }
    ];

    sops.secrets = listToAttrs (map
      (b: nameValuePair b.sshKeySecret { mode = "0400"; })
      cfg.remoteBuilders);

    nix = {
      distributedBuilds = true;
      # The builder pulls dependencies straight from the substituters instead
      # of this machine uploading them over the builder's link.
      settings.builders-use-substitutes = true;
      buildMachines = map
        (b: {
          inherit (b) hostName systems sshUser maxJobs speedFactor supportedFeatures publicHostKey;
          protocol = "ssh-ng";
          sshKey = (config.sops.secrets.${b.sshKeySecret} or { path = "/run/secrets/${b.sshKeySecret}"; }).path;
        })
        cfg.remoteBuilders;
    };

    # NOTE: programs.ssh.extraConfig is the SYSTEM-WIDE client config
    # (/etc/ssh/ssh_config), not a root-only one -- but each block is scoped
    # to `Host <builder>`, so nothing changes for any other destination. The
    # deliberate consequence is that an interactive `ssh <builder>` by a human
    # also gives up after 5s rather than hanging on a sleeping laptop; a user
    # who wants to wait can override it in their own ~/.ssh/config, which is
    # read first.
    programs.ssh.extraConfig = concatMapStrings
      (b: ''
        Host ${b.hostName}
          ConnectTimeout 5
          ServerAliveInterval 10
          ServerAliveCountMax 3
      '')
      cfg.remoteBuilders;
  };
}
