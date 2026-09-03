# The generic half of running a role: an account, directories, an identity, a
# container. Every fact below was learned by getting it wrong on a live host, so
# each carries the failure it prevents rather than just the rule.
{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.my.infra.ociRoles;

  # Where a role's host-side state lives. One parent for all of them, so a host
  # running three roles has one place to look.
  prepareUnit = name: role:
    let inherit (role) stateDir; in
    nameValuePair "${name}-prepare" {
      description = "Prepare ${name}'s directories and identity";
      # requiredBy, not wantedBy: a role that starts without its identity does
      # not fail usefully -- radicle-node exits 243/CREDENTIALS from inside a
      # nested boot, where the reason is three logs deep.
      requiredBy = [ "podman-${name}.service" ];
      before = [ "podman-${name}.service" ];
      after = [ "systemd-tmpfiles-setup.service" ];

      # THE ORDERING THAT MATTERS, and the reason this is a unit rather than
      # tmpfiles rules. On the activation that FIRST introduces a persisted
      # directory the impermanence bind mount does not exist yet: activation
      # starts tmpfiles-resetup BEFORE the new .mount units, so rules land on
      # the pre-mount directory and the empty root:root backing from /persist is
      # then mounted straight over the ownership they just set. RequiresMountsFor
      # makes systemd pull in and wait for those mounts, so everything below
      # writes to the persisted directory rather than the one about to be hidden
      # underneath it.
      #
      # The symptom when this is wrong names neither the mount nor the
      # ownership: `stat /var/lib/<user>/.config: no such file or directory`
      # from podman's pre-start, after which the unit trips its start limit and
      # stops retrying, so it stays failed even once the mount is fine.
      unitConfig.RequiresMountsFor =
        [ "/var/lib/${role.user}" stateDir ]
        ++ optional (role.identityDir != null) (toString role.identityDir);

      path = [ pkgs.sops ];
      serviceConfig = { Type = "oneshot"; RemainAfterExit = true; };
      script = ''
        set -euo pipefail
        umask 077

        # `install -d` sets mode and owner on a directory that already exists,
        # so this is idempotent and also heals a uid change.
        #
        # Owned by the ROLE'S ACCOUNT, never root, and that is load-bearing in a
        # way that is easy to get backwards. Rootless podman maps this account
        # to container ROOT and its subuids to 1..65536; host root maps to
        # NOTHING, so a root-owned directory arrives inside with an unmapped
        # owner and the container cannot chown it at all.
        install -d -m 0700 -o ${role.user} -g ${role.user} /var/lib/${role.user}
        install -d -m 0700 -o ${role.user} -g ${role.user} ${stateDir}
        ${concatMapStringsSep "\n" (v: ''
          install -d -m 0700 -o ${role.user} -g ${role.user} ${stateDir}/${v}
        '') (attrNames role.stateVolumes)}

        # Recursive over the account's OWN podman storage, which really does
        # belong to it on this host and which a uid change would otherwise
        # strand.
        #
        # NEVER over ${stateDir}: those files belong to the CONTAINER's users,
        # mapped into a subordinate range. Rewriting them to this account makes
        # them root INSIDE, and a service that drops privileges then loses its
        # own state -- which is exactly how a builder lost access to its
        # keystore, crash-looping with `Unlocking node keystore.. Permission
        # denied` while `systemctl --failed` stayed empty, because a unit in
        # auto-restart reports `activating`.
        chown -R ${role.user}:${role.user} /var/lib/${role.user}
      '' + optionalString (role.identityDir != null) ''

        # 0711: TRAVERSABLE but not listable. A service inside reads its
        # identity after dropping privileges, and this host's account maps to
        # container root -- so a 0700 directory blocks it at the PATH even when
        # the file itself is readable. That failure is indistinguishable from a
        # bad file mode: both are `Permission denied` on the same open().
        install -d -m 0711 -o ${role.user} -g ${role.user} ${toString role.identityDir}
        IDENTITY_DIR=${toString role.identityDir}
        export IDENTITY_DIR
        ${role.identityScript}

        # Own by NAME on every start: the uid is allocated by NixOS and can
        # change, and files chowned to a stale number would leave the role
        # unable to read its own identity -- surfacing as podman complaining
        # about .config rather than as anything naming the identity.
        chown -R ${role.user}:${role.user} ${toString role.identityDir}
        chmod 0711 ${toString role.identityDir}
      '';
    };

  containerOf = name: role:
    let inherit (role) stateDir; in
    nameValuePair name {
      # Streamed straight from the role -- no registry, no tarball in the store.
      imageStream = role.system.config.system.build.image;
      # `localhost/` is not decoration: podman refuses an unqualified short name
      # ("did not resolve to an alias and no unqualified-search registries are
      # defined"), and defining a search registry for an image that is loaded
      # locally and must never be fetched would be the wrong fix.
      image = "localhost/${name}:${role.system.config.my.system.ociImage.tag}";
      podman.user = role.user;

      volumes =
        optional (role.identityDir != null)
          "${toString role.identityDir}:${toString role.identityDir}:ro"
        ++ mapAttrsToList (host: guest: "${stateDir}/${host}:${guest}") role.stateVolumes;

      extraOptions =
        map (c: "--cap-add=${c}") role.capabilities
        ++ map (d: "--device=${d}") role.devices
        ++ [
          # systemd as PID 1 needs /run, /run/lock and the cgroup hierarchy as
          # tmpfs. podman does that in "systemd mode", which it auto-enables
          # ONLY when the command is literally /sbin/init, /usr/sbin/init,
          # /usr/local/sbin/init or systemd. A NixOS toplevel is a store path
          # ending in /init, which matches none of them -- so it must be forced.
          # Without it systemd execs and dies instantly, printing nothing, which
          # reads as a broken image and is not one.
          "--systemd=always"
          "--security-opt=no-new-privileges"

          # NO --userns=auto. It allocates a FRESH uid range per container, so
          # the host uid owning the identity files is not mapped inside -- the
          # read-only mount then reads as an unmapped owner and fails with
          # `permission denied`, which looks like a mode problem and is not one.
          # Plain rootless podman maps this host account to container root,
          # which is what makes a read-only identity mount readable at all.
          #
          # The isolation it reaches for belongs at a different seam: one
          # account per role, which `user` above makes the default.
          "--pids-limit=${toString role.pidsLimit}"
          "--memory=${role.memory}"
          "--memory-swap=${role.memory}"
        ]
        ++ role.extraOptions;
    };
in
{
  config = mkIf (cfg != { }) {
    users.users = mapAttrs'
      (_name: role: nameValuePair role.user {
        isSystemUser = true;
        group = role.user;
        # NO STATIC uid or gid. NixOS knows what is already taken and a
        # hand-picked number does not: a pin of 989 on this fleet was silently
        # shared with usbmux, which had been allocated it dynamically first, and
        # NixOS does not reject a duplicate -- the two accounts simply became
        # one principal. Nothing here needs the number to be predictable,
        # because every directory is owned by NAME.
        home = "/var/lib/${role.user}";
        createHome = true;
        # The container is a system service that must come up at boot with
        # nobody logged in; oci-containers orders itself after
        # linger-users.service when it sees a non-root podman.user.
        linger = true;
        autoSubUidGidRange = true; # rootless podman maps into a subordinate range
      })
      cfg;

    users.groups = mapAttrs' (_: role: nameValuePair role.user { }) cfg;

    # Only the shared parent, which is not persisted and so has no bind mount to
    # race with. Everything under it is prepared by the per-role unit above.
    # The PARENT of each role's stateDir, whatever the host chose. Not
    # persisted and not per-role, so there is no bind mount to race with;
    # everything under it is prepared by the per-role unit above.
    systemd.tmpfiles.rules =
      map (d: "d ${d} 0755 root root -")
        (unique (mapAttrsToList (_: role: dirOf role.stateDir) cfg));

    systemd.services =
      mapAttrs' prepareUnit cfg
      # oci-containers gives a `podman.user` unit a PATH of podman's own bin and
      # nothing else. podman locates its OCI runtime through a helper-binary
      # wrapper that normally sits on the SYSTEM profile PATH, so without this it
      # fails with `default OCI runtime "crun" not found: invalid argument`,
      # which reads as a missing package and is a missing PATH entry.
      // mapAttrs' (name: _: nameValuePair "podman-${name}" { path = [ pkgs.crun ]; }) cfg;

    # Stated here rather than left to a developer-tooling flag: a host must be
    # able to run a role with my.dev.enable = false. Unpersisted, a reboot loses
    # every role's identity, tailnet registration and storage together --
    # silently, and only on reboot.
    my.system.persistence.features.systemDirectories =
      [ "/var/lib/containers" ]
      ++ concatLists (mapAttrsToList
        (_name: role:
          [ "/var/lib/${role.user}" role.stateDir ]
          ++ optional (role.identityDir != null) (toString role.identityDir))
        cfg);

    virtualisation.oci-containers = {
      backend = "podman";
      containers = mapAttrs' containerOf cfg;
    };
  };
}
