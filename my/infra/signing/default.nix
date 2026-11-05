# Signing services: see ./options.nix for the interface.
#
# The key is root-owned at rest and reaches the handler through LoadCredential,
# in a directory only the service's account can open. A client gets a connection
# and nothing else, so it can ask for a signature but cannot read the key or sign
# without the handler.
#
# This separates accounts, and root is on the other side of that line: anything
# that can deploy a system configuration on this host can reach the key.
{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.my.infra.signing;

  socketPath = name: "/run/signing/${name}.sock";
  clientAcl = svc: concatMapStringsSep " " (client: "-m u:${client}:rw") svc.clients;
in
{
  config = mkIf (cfg.services != { }) {
    assertions = [
      {
        assertion = config.my.secrets.enable;
        message = "my.infra.signing delivers its keys through sops and requires my.secrets.enable = true.";
      }
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

    # Root-owned, mode 0400: systemd reads LoadCredential sources as root before
    # User= drops privileges.
    sops.secrets = mapAttrs' (_: svc: nameValuePair svc.secret { mode = "0400"; }) cfg.services;

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

      services = mapAttrs'
        (name: svc: nameValuePair "signing-${name}@" {
          description = "Signing service ${name}, one connection";
          # A switch must not cut a signature off; the next connection gets the
          # new configuration anyway.
          restartIfChanged = false;
          stopIfChanged = false;
          serviceConfig = {
            ExecStart = escapeShellArgs ([ (getExe svc.handler) ] ++ svc.handlerArgs);
            User = svc.user;
            Group = svc.user;
            StandardInput = "socket";
            StandardOutput = "socket";
            StandardError = "journal";
            LoadCredential = "signing-key:${config.sops.secrets.${svc.secret}.path}";
            BindReadOnlyPaths = svc.readOnlyPaths;

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
        })
        cfg.services;
    };
  };
}
