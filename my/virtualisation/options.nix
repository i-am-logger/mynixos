# my.virtualisation — the machines this host runs inside itself.
#
# A capability, not an infrastructure service, which is why it is here rather
# than under `my.infra` where it started life as `ociRoles`. Nothing about it is
# radicle's: a host runs OTHER MYNIXOS SYSTEMS, and what those systems do is
# their own business. An `ollama` machine that enables `my.ai` and nothing else
# is the same construct as a radicle seed, and so is `yoga` itself.
#
# EVERY NAME DERIVES FROM THE GUEST. The container is named by the guest's
# `my.system.hostname`, and its host-side account from that again. The name used
# to exist twice -- once as an attribute key here, once inside the guest -- and
# the two have already disagreed: a suffix-vs-full-name mix-up produced
# `radicle-radicle-yoga-seed`, where the image built, the container ran, and the
# only damage was a seed advertising an address nobody could dial. Deriving
# makes that unrepresentable rather than merely tested.
#
# RESOURCE LIMITS ARE THE HOST'S, and that is not the same answer nixpkgs gives
# for VMs. A VM's `virtualisation.memorySize` is virtual hardware -- the guest
# genuinely has that much and wants it wherever it runs, so it belongs to the
# guest. A container's limit is a cgroup ceiling the HOST imposes to defend
# itself against a guest that can fork-bomb it. Two different things wearing one
# word, and only the second is written here.
{ lib, ... }:

let
  # A guest is written as a bare system in the common case:
  #
  #   my.virtualisation.containers = [ radicle-seed radicle-builder ];
  #
  # and as an attrset only when the HOST has something to contribute that the
  # guest cannot know -- which is, in practice, exactly one thing: decryption.
  # `coercedTo` is what lets both spellings be the same option, so the simple
  # case stays a list of machines and the hard case is still expressible.
  guest = lib.types.submodule ({ config, ... }: {
    options = {
      system = lib.mkOption {
        type = lib.types.raw;
        description = ''
          The evaluated guest system. Its `config.system.build.image` is
          streamed straight to podman -- no registry, and no tarball in the
          store.
        '';
      };

      name = lib.mkOption {
        type = lib.types.str;
        default = config.system.config.my.system.hostname;
        defaultText = lib.literalExpression "the guest's my.system.hostname";
        description = ''
          Container name. Derived from the guest and not normally set: it is
          also the guest's hostname and, because tailscaled runs inside, its
          name on the tailnet -- which must be unique FLEET-wide, since
          tailscale does not reject a collision but silently appends -1.
        '';
      };

      user = lib.mkOption {
        type = lib.types.str;
        default = "${config.name}-user";
        defaultText = lib.literalExpression "\"\${name}-user\"";
        description = ''
          The unprivileged account owning this guest's podman storage.

          ONE ACCOUNT PER GUEST, and that is a boundary rather than tidiness:
          rootless podman gives an account one storage tree, one subuid range
          and one control surface. A guest running repository-supplied shell
          must not share an account with one holding a key that is expensive to
          rotate, because an escape from the first would reach the second's
          identity directory and its podman socket.

          Never root, and never a human's account: a podman bug then costs this
          account rather than the machine.
        '';
      };

      identityDir = lib.mkOption {
        type = lib.types.nullOr lib.types.path;
        default = null;
        description = ''
          Directory bind-mounted read-only at the same path inside, holding
          this guest's identity. Null for a guest that needs none.

          The IMAGE is identity-free and the CONTAINER is identified, which is
          what lets several guests share one image and differ only in what is
          mounted here.
        '';
      };

      identityScript = lib.mkOption {
        type = lib.types.lines;
        default = "";
        description = ''
          Shell run as root before the container starts, with `$IDENTITY_DIR`
          set, to place decrypted material in `identityDir`.

          THE ONE THING THE HOST MUST DO AND THE GUEST CANNOT, which is why
          this option exists on this side at all: sops-install-secrets mounts a
          ramfs for its secrets directory -- a tmpfs under `sops.useTmpfs`, but
          still mount(2) -- and that needs CAP_SYS_ADMIN. A guest running
          repository-supplied shell must not have it, so the two requirements
          cannot both be met inside the container. systemd's `LoadCredential`
          is unavailable for the same reason: it builds
          `$CREDENTIALS_DIRECTORY` by mounting.
        '';
      };

      stateDir = lib.mkOption {
        type = lib.types.path;
        default = "/var/lib/machines/${config.name}";
        description = ''
          Where this host keeps the guest's state volumes.

          Changing it does not migrate anything -- podman simply mounts the new
          location, so the guest comes up on EMPTY state and its previous
          identity is stranded at the old path. That is a silent failure: the
          container is running and healthy, it has just forgotten who it is.
        '';
      };

      stateVolumes = lib.mkOption {
        type = lib.types.attrsOf lib.types.path;
        default = { };
        example = { radicle = "/var/lib/radicle"; };
        # A ROLE'S JOURNAL IS ALWAYS READABLE FROM THE HOST.
        #
        # systemd is PID 1 inside a role, so its units log to the role's own
        # journal -- a file on a filesystem the host never mounts. podman's
        # journald driver captures the container's stdout, which after PID 1
        # hands off is only the two lines systemd prints before it starts
        # logging internally. `journalctl -u podman-<role>` on the host
        # therefore ends at "starting systemd..." and every unit failure inside
        # is invisible.
        #
        # That is not a small inconvenience: it is the difference between
        # reading why a broker stopped and guessing at it. Without this, the
        # ways in are `podman exec` as the role's account -- manual, root-
        # requiring, part of no configuration -- or inferring state from
        # whatever the role serves over HTTP, which cannot distinguish a live
        # service from a dead one whose last status page is still being served.
        #
        # Mounting /var/log/journal is the whole fix. journald's default
        # Storage=auto becomes PERSISTENT exactly because that directory now
        # exists, so the guest needs no configuration at all, and the host
        # reads it with `journalctl -D <stateDir>/journal -u <unit>` -- full
        # structured logs, per-unit filtering, `-f` to follow.
        #
        # NOT ForwardToConsole=yes: that writes to systemd's TTYPath
        # (/dev/console), and podman without --tty gives the container no
        # console device conmon captures, so it reaches nothing. Tried, and it
        # silently did nothing.
        apply = v: v // { journal = "/var/log/journal"; };
        description = ''
          `<stateDir>/<name>` mounted at `<path>` inside.

          EXPLICIT, because oci-containers runs `podman rm -f` in its pre-start:
          the container is destroyed and rebuilt on every image change, so
          anything not named here is anything the guest may not keep.

          `journal` is added automatically and need not be listed: a role whose
          logs cannot be read from the host is a role that can only be debugged
          by hand.
        '';
      };


      # WHY THESE ARE HOST-SIDE AND `virtualisation.memorySize` IS NOT.
      #
      # A VM's memory is virtual hardware: the guest genuinely has that much,
      # wants it wherever it runs, and nixpkgs rightly puts it in the guest's
      # own config. A container's limit is the opposite -- a cgroup ceiling the
      # HOST imposes to defend itself, because a guest running
      # repository-supplied shell can fork-bomb or exhaust memory and nothing
      # else addresses denial of service against the machine underneath. Two
      # different things wearing one word.
      #
      # So a host may lower them for a guest it does not fully trust, and a
      # guest cannot raise them.
      memory = lib.mkOption {
        type = lib.types.str;
        default = "4g";
        description = "cgroup memory ceiling (podman --memory and --memory-swap).";
      };

      pidsLimit = lib.mkOption {
        type = lib.types.int;
        default = 2048;
        description = "cgroup pid ceiling, which is what stops a fork bomb.";
      };

      capabilities = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ "NET_ADMIN" "NET_RAW" ];
        description = "Capabilities added to the container's bounding set.";
      };

      devices = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ "/dev/net/tun" ];
        description = "Host devices exposed to the container.";
      };

      nixSandbox = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          Let this guest run nix builds in nix's own sandbox. TWO things are
          needed, and neither is a capability. Both were measured by building a
          one-line derivation in this image under each combination, not
          reasoned from the error text -- which misleads about both.

          `/proc` FULLY VISIBLE. Nix clones its namespaces and REMOUNTS /proc,
          and the kernel refuses that remount while anything is mounted over a
          path inside /proc -- which podman does by default for ten paths.
          Without the unmask nix stops at its namespace probe: "this system does
          not support the kernel namespaces that are required for sandboxing",
          which reads as a missing capability and invites `--no-sandbox`.

          A SECCOMP EXCEPTION for sethostname and setdomainname. Nix names the
          UTS namespace it just created, so a build cannot observe which machine
          it ran on. podman's default profile ERRNOs both syscalls whenever
          CAP_SYS_ADMIN is absent from the bounding set, and the choice is made
          once at container creation. The build dies with "cannot set host name:
          Operation not permitted" from inside an unrelated derivation, naming
          the last syscall rather than the filter. See nixSandboxSeccomp in
          ../containers/default.nix for why the kernel would have allowed it.

          WHAT THIS IS NOT. It is not CAP_SYS_ADMIN, which also fixes it and is
          a far larger grant -- real mount(2), bpf, quotactl for container PID 1
          -- and which this fleet forbids a guest that runs repository-supplied
          shell (see identityScript above). Under the seccomp exception the
          syscall is unblocked and the AUTHORITY is not: the kernel still
          requires the capability in the user namespace owning the target UTS
          namespace, so a build can only rename a namespace it created itself.
          Verified in the image -- the build succeeds, `hostname` in the
          container's own namespace is still refused, and mount still fails.

          Isolation is otherwise unaffected: the container keeps its own PID
          namespace, so an unmasked /proc shows only its own processes, and this
          grants no device and no view of the host. The sandbox stays ON, which
          is the point of building on nix at all.
        '';
      };

      extraOptions = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "Additional podman flags, appended after the derived ones.";
      };
    };
  });
in
{
  virtualisation = lib.mkOption {
    description = "Other mynixos systems this host runs inside itself";
    default = { };
    type = lib.types.submodule {
      options = {
        containers = lib.mkOption {
          default = [ ];
          example = lib.literalExpression "[ radicle-seed radicle-builder ]";
          description = ''
            Machines this host builds as OCI images and runs as rootless podman
            containers. A bare system is the common spelling; an attrset adds
            what only the host can supply.
          '';
          # A bare system and an entry attrset are BOTH attrsets, so the
          # discriminator has to be explicit: an evaluated system has `.config`
          # and an entry does not. It goes on the COERCED type, because
          # `coercedTo` coerces whenever that type's check passes -- with
          # `raw` there (whose check is `x: true`) every entry was wrapped as
          # `{ system = <entry>; }`, and the failure surfaced as "attribute
          # 'config' missing" from inside the `name` default rather than
          # anywhere near the option that was written.
          type = lib.types.listOf (
            lib.types.coercedTo
              (lib.types.addCheck lib.types.raw (x: builtins.isAttrs x && x ? config))
              (s: { system = s; })
              guest
          );
        };
      };
    };
  };
}
