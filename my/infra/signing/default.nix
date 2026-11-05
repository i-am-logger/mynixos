# Signing services: see ./options.nix for the interface.
#
# The machine generates each key, as the service's own account, the first time it
# is needed, and keeps it under /var/lib. A client gets a connection and nothing
# else, so it can ask for a signature but cannot read the key or sign without the
# handler. The handler gets the key through LoadCredential, in a directory only
# its account can open.
#
# This separates accounts, and root and raw disk access are on the other side of
# that line: an account in the `disk` group can read the key off the device, and anything
# that can deploy a system configuration on this host can reach the key.
{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.my.infra.signing;

  socketPath = name: "/run/signing/${name}.sock";
  clientAcl = svc: concatMapStringsSep " " (client: "-m u:${client}:rw") svc.clients;

  confinement = {
    UMask = "0077";
    LimitCORE = 0;
    CapabilityBoundingSet = "";
    NoNewPrivileges = true;
    PrivateNetwork = true;
    RestrictAddressFamilies = "AF_UNIX";
    ProtectSystem = "strict";
    ProtectHome = "tmpfs";
    PrivateTmp = true;
    PrivateDevices = true;
    PrivateIPC = true;
    ProtectProc = "invisible";
    ProcSubset = "pid";
    ProtectClock = true;
    ProtectControlGroups = true;
    ProtectHostname = true;
    ProtectKernelLogs = true;
    ProtectKernelModules = true;
    ProtectKernelTunables = true;
    KeyringMode = "private";
    LockPersonality = true;
    MemoryDenyWriteExecute = true;
    RestrictNamespaces = true;
    RestrictRealtime = true;
    RestrictSUIDSGID = true;
    SystemCallArchitectures = "native";
    SystemCallFilter = [ "@system-service" "~@privileged @resources" ];
  };

  # The public half is moved into place first, so a key at its path always has one.
  keygen = name: pkgs.writeShellScript "signing-${name}-keygen" ''
    set -eu
    cd "$STATE_DIRECTORY"
    if [ ! -e key ]; then
      ${pkgs.coreutils}/bin/rm -f key.new key.new.pub
      ${pkgs.openssh}/bin/ssh-keygen -q -t ed25519 -N "" -C ${escapeShellArg name} -f key.new
      ${pkgs.coreutils}/bin/chmod 0644 key.new.pub
      ${pkgs.coreutils}/bin/chmod 0400 key.new
      ${pkgs.coreutils}/bin/mv key.new.pub key.pub
      ${pkgs.coreutils}/bin/mv key.new key
    fi
  '';
in
{
  config = mkIf (cfg.services != { }) {
    assertions = [
      {
        # LoadCredential builds its directory by mounting, which a rootless
        # container has no capability for; see my/infra/radicle/default.nix.
        assertion = !config.boot.isContainer;
        message = "my.infra.signing needs LoadCredential, which a rootless container cannot provide.";
      }
    ] ++ concatLists (mapAttrsToList
      (name: svc: map
        (client: {
          assertion = config.users.users ? ${client};
          message = "my.infra.signing.services.${name}.clients names `${client}`, which is not an account on this host.";
        })
        svc.clients)
      cfg.services);

    users = {
      users = mapAttrs'
        (name: svc: nameValuePair svc.user {
          isSystemUser = true;
          group = svc.user;
          description = "Signing service ${name}";
        })
        cfg.services;
      groups = mapAttrs' (_: svc: nameValuePair svc.user { }) cfg.services;
    };

    my.system.persistence.features.systemDirectories =
      mapAttrsToList (_: svc: "/var/lib/${svc.user}") cfg.services;

    systemd = {
      sockets = mapAttrs'
        (name: svc: nameValuePair "signing-${name}" {
          description = "Signing service ${name}";
          wantedBy = [ "sockets.target" ];
          socketConfig = {
            ListenStream = socketPath name;
            # One handler per connection, so a request sees no state from another.
            Accept = true;
            SocketUser = "root";
            SocketGroup = "root";
            SocketMode = "0600";
            ExecStartPost = mkIf (svc.clients != [ ])
              "${pkgs.acl}/bin/setfacl ${clientAcl svc} ${socketPath name}";
          };
        })
        cfg.services;

      services = mkMerge (mapAttrsToList
        (name: svc: {
          "signing-${name}-keygen" = {
            description = "Signing service ${name}, generates its key once";
            wantedBy = [ "multi-user.target" ];
            restartIfChanged = false;
            serviceConfig = confinement // {
              Type = "oneshot";
              RemainAfterExit = true;
              ExecStart = keygen name;
              User = svc.user;
              Group = svc.user;
              StateDirectory = svc.user;
              # The public key is for anyone; the private key is 0400.
              StateDirectoryMode = "0755";
            };
          };

          "signing-${name}@" = {
            description = "Signing service ${name}, one connection";
            requires = [ "signing-${name}-keygen.service" ];
            after = [ "signing-${name}-keygen.service" ];
            # A switch must not cut a signature off; the next connection gets the
            # new configuration anyway.
            restartIfChanged = false;
            stopIfChanged = false;
            serviceConfig = confinement // {
              ExecStart = escapeShellArgs ([ (getExe svc.handler) ] ++ svc.handlerArgs);
              User = svc.user;
              Group = svc.user;
              StandardInput = "socket";
              StandardOutput = "socket";
              StandardError = "journal";
              LoadCredential = "signing-key:/var/lib/${svc.user}/key";
              BindReadOnlyPaths = svc.readOnlyPaths;
            };
          };
        })
        cfg.services);
    };
  };
}
