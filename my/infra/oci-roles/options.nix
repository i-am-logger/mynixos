# my.infra.ociRoles — how a HOST runs a role, once, instead of per role.
#
# A role is a machine: its own init, its own NID, its own tailnet node. What a
# host does with one is entirely generic — make an unprivileged account, prepare
# directories the container will own, put the identity where the role reads it,
# and hand podman an image. None of that varies with what the role IS.
#
# WHY THIS EXISTS AS AN ABSTRACTION AT ALL, stated plainly because "shared
# boilerplate" is a weak reason on its own. yoga ran two roles whose hosting was
# copy-pasted: 94 lines for the seed, 91 for the builder, using an identical
# construct list around 24 and 14 lines of actual machine definition. The copies
# then DRIFTED in the one place that mattered — the builder's recursive `Z`
# tmpfiles rule healed a uid change, while the seed, copied from it before that
# rule was understood, lost its first boot to a tmpfiles/mount ordering race.
# Two copies of a thing that is hard to get right is one copy that is wrong.
#
# Type-only second declaration of `my.infra`: my/infra/options.nix owns the
# description and default, and duplicating those would collide. Submodule TYPES
# merge, so this adds `ociRoles` to the existing option and platforms/linux.nix
# stays the thing that decides reach.
{ lib, ... }:

{
  infra = lib.mkOption {
    type = lib.types.submodule {
      options.ociRoles = lib.mkOption {
        default = { };
        description = ''
          Roles this host builds and runs as OCI containers. The attribute name
          is the container name, the role's hostname, and — because tailscaled
          runs inside — its name on the tailnet, so it must be unique
          FLEET-wide: tailscale does not reject a collision, it silently
          appends -1, leaving two hosts' roles indistinguishable in the one
          place you would look to tell them apart.
        '';
        type = lib.types.attrsOf (lib.types.submodule ({ name, ... }: {
          options = {
            system = lib.mkOption {
              type = lib.types.raw;
              description = ''
                The evaluated role system, as returned by a role function such
                as `mynixos.lib.roles.radicle.seed`. Its
                `config.system.build.image` is streamed straight to podman —
                no registry, and no tarball in the store.
              '';
            };

            user = lib.mkOption {
              type = lib.types.str;
              default = "${name}-host";
              description = ''
                The unprivileged account that owns this role's podman storage.

                ONE ACCOUNT PER ROLE, and that is a boundary rather than a
                convention: rootless podman gives an account one storage tree,
                one subuid range and one control surface. A role that runs
                repository-supplied shell — a CI builder — must not share an
                account with one holding a key that is expensive to rotate,
                because an escape from the first would reach the second's
                identity directory and its podman socket.

                Never root, and never a human's account: a podman bug then
                costs this account rather than the machine.
              '';
            };

            identityDir = lib.mkOption {
              type = lib.types.nullOr lib.types.path;
              default = null;
              description = ''
                Directory bind-mounted read-only at the same path inside,
                holding this role's identity. Null for a role that needs none.

                The IMAGE is identity-free and the CONTAINER is identified,
                which is what lets several roles share one image and differ
                only in what is mounted here.
              '';
            };

            identityScript = lib.mkOption {
              type = lib.types.lines;
              default = "";
              description = ''
                Shell run as root before the container starts, with
                `$IDENTITY_DIR` set, to place decrypted material in
                `identityDir`.

                DECRYPTION HAPPENS HERE, ON THE HOST, and not inside the role.
                sops-install-secrets mounts a ramfs for its secrets directory —
                a tmpfs under `sops.useTmpfs`, but still `mount(2)` — which
                needs CAP_SYS_ADMIN. A role running repository-supplied shell
                must not have it, so the two requirements cannot both be met
                inside the container. systemd's `LoadCredential` is unavailable
                for the same reason: it builds `$CREDENTIALS_DIRECTORY` by
                mounting.
              '';
            };

            stateDir = lib.mkOption {
              type = lib.types.path;
              default = "/var/lib/oci-roles/${name}";
              description = ''
                Where this host keeps the role's state volumes.

                THE HOST DECLARES THIS, and the default is only a default,
                because the path is not an implementation detail: it is where a
                running role's storage and tailnet registration already live.
                Changing it does not migrate anything -- podman simply mounts
                the new location, so the role comes up on EMPTY state and its
                previous identity is stranded at the old path. That is a silent
                failure with a loud consequence: the node re-registers under a
                new tailnet identity and holds none of its repositories.
              '';
            };

            stateVolumes = lib.mkOption {
              type = lib.types.attrsOf lib.types.str;
              default = { };
              example = { radicle = "/var/lib/radicle"; tailscale = "/var/lib/tailscale"; };
              description = ''
                Directories this host keeps across container recreation, as
                host-subdirectory -> path inside the container.

                NOT optional for anything that must survive: oci-containers
                runs `podman rm -f` in its pre-start, so the container is
                destroyed on every image change — and on nixos-unstable the
                image moves whenever the closure does. A tailnet registration
                left unpersisted has to be redone by hand after every rebuild,
                and leaves a trail of dead nodes behind it.
              '';
            };

            capabilities = lib.mkOption {
              type = lib.types.listOf lib.types.str;
              default = [ "NET_ADMIN" "NET_RAW" ];
              description = ''
                Linux capabilities added to the container.

                NET_ADMIN is not only for tailscaled: nixpkgs' firewall.service
                carries `ConditionCapability=CAP_NET_ADMIN`, and systemd SKIPS
                a unit whose condition is unmet rather than failing it. Without
                it a role comes up reporting `running`, with zero failed units
                and an EMPTY ruleset.

                SYS_ADMIN is deliberately absent and should stay absent — it is
                what would let a role mount, and withholding it is the whole
                reason identity is decrypted on the host.
              '';
            };

            devices = lib.mkOption {
              type = lib.types.listOf lib.types.str;
              default = [ "/dev/net/tun" ];
              description = "Host devices exposed to the container; tailscaled needs the tun device.";
            };

            memory = lib.mkOption {
              type = lib.types.str;
              default = "4g";
              description = ''
                Memory ceiling. Swap is pinned to the same value, so the role
                cannot trade thrash for its limit.
              '';
            };

            pidsLimit = lib.mkOption {
              type = lib.types.int;
              default = 2048;
              description = ''
                Process ceiling. For a role running repository-supplied shell
                this and `memory` are the only things standing between a
                fork-bomb and the host.
              '';
            };

            extraOptions = lib.mkOption {
              type = lib.types.listOf lib.types.str;
              default = [ ];
              description = "Additional podman flags, appended after the ones this module derives.";
            };
          };
        }));
      };
    };
  };
}
