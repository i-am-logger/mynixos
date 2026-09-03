# Radicle CI: broker + native adapter instances, one trigger per adapter.
#
# One broker fleet-wide, on the seed host. Job results are COBs that do not
# aggregate across brokers, so a single broker gives one coherent verdict
# stream -- and nix's own daemon is already the multi-arch scheduler: one
# `nix build` fans out across the local builder, binfmt qemu (aarch64-linux,
# on for every my.dev host) and the darwin remote builder declared in
# my.dev.remoteBuilders.
#
# SECURITY: the nixpkgs broker unit shares RAD_HOME with the node and
# bind-mounts the decrypted node key into its namespace -- repository-supplied
# recipes run with read access to the node's identity. Acceptable ONLY because
# this network is tailnet-private, every repo writer is us, and the mandatory
# `Node` trigger filter below pins exactly whose pushes may trigger a run.
{ config
, lib
, pkgs
, ...
}:

with lib;

let
  cfg = config.my.infra.radicle;

  # WAIT FOR THE NODE'S CONTROL SOCKET, because ordering does not.
  #
  # The broker is `after` and `bindsTo` radicle-node, and neither means what is
  # needed here: radicle-node is a `simple` service, so systemd considers it
  # started the moment it EXECS -- long before it has created
  # $RAD_HOME/node/control.sock. The broker then subscribes, finds no socket,
  # and treats it as unrecoverable:
  #
  #   ERROR: failed to add events to queue
  #   caused by: failed to subscribe to node events
  #   caused by: node control socket does not exist: /var/lib/radicle/node/control.sock
  #   CI broker ends in unrecoverable error
  #
  # systemd restarts it and the second attempt usually wins, so the unit ends up
  # `active` and the failure is invisible in anything but the journal. What it
  # costs is not nothing: events that arrive inside that window are never
  # queued, so a push landing just after a restart produces no CI run at all --
  # and a container restarts on every image change.
  #
  # Bounded rather than infinite: a node that never opens its socket is a real
  # failure and must still surface as one, just with a message that says so
  # instead of a race that reads as a broker bug.
  waitForNodeSocket = pkgs.writeShellScript "radicle-ci-broker-wait-for-node" ''
    sock=${radProfile.radHome}/node/control.sock
    for _ in $(seq 1 120); do
      [ -S "$sock" ] && exit 0
      sleep 1
    done
    echo "radicle-node control socket did not appear at $sock after 120s." >&2
    echo "The broker subscribes to the node's event stream and cannot start" >&2
    echo "without it; check radicle-node.service." >&2
    exit 1
  '';

  radProfile = import ./rad-profile.nix {
    inherit config pkgs;
    inherit (cfg) publicKey;
  };

  # The darwin remote builder, if the host declares one. The probe uses the
  # builder's real host name on TCP 22: reachability needs no credentials,
  # and the ssh key is root-owned -- the broker could not use it anyway.
  darwinBuilders =
    filter (b: elem "aarch64-darwin" b.systems) config.my.dev.remoteBuilders;
  darwinBuilderHost =
    if darwinBuilders == [ ] then null else (head darwinBuilders).hostName;

  # The one thing repo recipes call. Keeps the darwin-asleep policy out of
  # every repo's .radicle/native.yaml:
  #   radicle-ci-build linux  <installable>...
  #   radicle-ci-build darwin --policy required|best-effort|off <installable>...
  radicle-ci-build = pkgs.writeShellApplication {
    name = "radicle-ci-build";
    runtimeInputs = [ pkgs.nix pkgs.bash pkgs.coreutils ];
    text = ''
      mode="''${1:-}"
      shift || { echo "usage: radicle-ci-build linux|darwin [--policy P] <installable>..." >&2; exit 2; }

      policy="required"
      if [ "''${1:-}" = "--policy" ]; then
        # ''${2:-} not $2: set -u would abort with an opaque "unbound
        # variable" if --policy were passed with no value.
        policy="''${2:-}"
        [ -n "$policy" ] || { echo "radicle-ci-build: --policy needs a value" >&2; exit 2; }
        shift 2
      fi

      # A recipe that forgets its installables must not silently build
      # whatever flake happens to be in the adapter's working directory.
      [ "$#" -gt 0 ] || {
        echo "radicle-ci-build: no installables given" >&2
        exit 2
      }

      case "$mode" in
        linux)
          exec nix build --no-link --print-build-logs "$@"
          ;;
        darwin)
          case "$policy" in
            off)
              echo "darwin build: policy off, skipping"
              exit 0
              ;;
            required | best-effort) ;;
            *)
              echo "radicle-ci-build: unknown --policy '$policy'" >&2
              exit 2
              ;;
          esac
          ${if darwinBuilderHost == null then ''
            echo "### DARWIN BUILD UNAVAILABLE -- no aarch64-darwin entry in my.dev.remoteBuilders ###"
            [ "$policy" = "best-effort" ] && exit 0
            exit 1
          '' else ''
            if ! timeout 5 bash -c 'exec 3<>/dev/tcp/${darwinBuilderHost}/22' 2>/dev/null; then
              echo "### DARWIN BUILD SKIPPED -- builder ${darwinBuilderHost} unreachable ###"
              [ "$policy" = "best-effort" ] && exit 0
              echo "darwin build is required and the builder is unreachable" >&2
              exit 1
            fi
            exec nix build --no-link --print-build-logs "$@"
          ''}
          ;;
        *)
          echo "radicle-ci-build: first argument must be 'linux' or 'darwin'" >&2
          exit 2
          ;;
      esac
    '';
  };
  # A role that actually runs builds, inside a container. Both halves matter:
  # a seed never builds, and on a host the unit's own confinement is the only
  # boundary there is.
  sandboxingBuilder = cfg.builder.enable && config.boot.isContainer;

in
{
  config = mkIf (cfg.enable && cfg.ci.enable) {
    assertions = [
      {
        assertion = cfg.ci.trustedNids != [ ];
        message = ''
          my.infra.radicle.ci.trustedNids must not be empty: without a Node
          trigger filter, any patch author executes arbitrary code on this
          host (with read access to the node key).
        '';
      }
    ];

    services.radicle.ci = {
      broker = {
        enable = true;
        settings = {
          triggers = mapAttrsToList
            (name: adapter: {
              adapter = name;
              filters = [{
                And = [
                  { HasFile = adapter.recipeFile; }
                  { Or = map (nid: { Node = nid; }) cfg.ci.trustedNids; }
                  { Or = adapter.events; }
                ];
              }];
            })
            cfg.ci.adapters;

          # nix-daemon HOME/cache for `nix build` run from recipes (flake
          # eval fetches inputs client-side and wants a writable cache).
          # Merges with the env.PATH the native adapter module writes.
          adapters = mapAttrs
            (_: _: {
              env = {
                HOME = config.services.radicle.ci.broker.stateDir;
                XDG_CACHE_HOME = "${config.services.radicle.ci.broker.stateDir}/.cache";
              };
            })
            cfg.ci.adapters;
        };
      };

      adapters.native.instances = mapAttrs
        (name: adapter: {
          # listOf merge CONCATENATES with upstream's unconditional base set
          # (bash, coreutils, git, ...); module-eval asserts nix survives the
          # merge so an upstream mkForce would fail CI here, not on a host.
          # A BUILDER CARRIES ITS OWN TOOLCHAIN -- not something the host lends
          # it. A host that had to supply these would make the machine depend on
          # where it happens to run, and the same machine on another host would
          # then build differently, silently.
          #
          #   devenv      what repository recipes invoke to get their own toolchain
          #   gnugrep     absent from upstream's adapter PATH (bash coreutils curl
          #               gawk gitMinimal gnused wget), so a recipe using grep
          #               fails mid-run as command-not-found, not as a missing dep
          #   util-linux  unshare(1), so a recipe can TEST whether it may create a
          #               nested user namespace instead of inferring it from a nix
          #               build that dies four levels down in "cannot set host name"
          #
          # Contributed here rather than from ./builder.nix because that file
          # declares options and so cannot name `pkgs`; this one already renders
          # the list.
          runtimePackages = [ pkgs.nix radicle-ci-build ]
            ++ adapter.extraRuntimePackages
            ++ optionals cfg.builder.enable [ pkgs.devenv pkgs.gnugrep pkgs.util-linux ];
        } // optionalAttrs (cfg.ci.serveReports.publicUrl != null) {
          # What turns a failed run into something a reader can open. The
          # adapter composes `${base_url}/${run_id}/log.html` and hands it to
          # the broker, which renders it in the Info column; upstream calls it
          # "mandatory for access from CI broker page", and unset it is the
          # difference between a verdict and a diagnosis.
          #
          # It cannot be derived here: this node is proxied by whatever fronts
          # it, and knows neither that host's name nor the path it is mounted
          # under. The path segment must match the nginx location above.
          settings.base_url = "${removeSuffix "/" cfg.ci.serveReports.publicUrl}/logs/${name}";
        })
        cfg.ci.adapters;
    };

    # A role serving its own CI reports: nginx, no explorer, no httpd. The
    # explorer's own ciReports path aliases report_dir on the SEED, which is
    # wrong the moment CI runs somewhere else -- and wrong silently, because an
    # empty report_dir renders as an empty directory listing.
    services.nginx = mkIf cfg.ci.serveReports.enable {
      enable = true;
      virtualHosts."radicle-ci-reports" = {
        # BOTH families. `listen [::]:port` in nginx is IPv6-ONLY unless the
        # socket says otherwise, and a tailnet peer may dial either -- yoga
        # reaches this over IPv4 and got connection refused while `ss` showed
        # something listening, which reads as a firewall problem and is not one.
        # radicle-node binds dual-stack, so the two looked identical in config
        # and behaved differently on the wire.
        listen = [
          { addr = "0.0.0.0"; port = cfg.ci.serveReports.listenPort; }
          { addr = "[::]"; port = cfg.ci.serveReports.listenPort; }
        ];
        locations = {
          "/" = {
            alias = "${config.services.radicle.ci.broker.settings.report_dir}/";
            # autoindex because a run is named after its id: without a listing
            # there is no way to reach one without already knowing it.
            extraConfig = "autoindex on;";
          };
        }
        # Per-run logs, which are NOT in report_dir. The broker's pages.rs
        # writes only the status page, the per-repository pages, status.json
        # and the RSS feeds -- never a run's output. The native adapter writes
        # that itself, to <state>/<run_id>/log.html, and hands the URL back
        # through base_url. Serving report_dir alone therefore publishes a list
        # of runs and their verdicts with no way to see why any of them failed,
        # which is what seven consecutive failures here looked like.
        // mapAttrs'
          (name: _: nameValuePair "/logs/${name}/" {
            alias = "${config.services.radicle.ci.broker.stateDir}/adapters/native/${name}/";
            # A run is named by a uuid recorded nowhere else, so without a
            # listing an old run is unreachable even though its log is there.
            extraConfig = "autoindex on;";
          })
          cfg.ci.adapters;
      };
    };

    # The report dir belongs to the radicle user; nginx needs group read to
    # serve it. Read-only -- nginx never writes there.
    users.users.nginx.extraGroups =
      optional (cfg.ci.serveReports.enable && cfg.ci.enable) "radicle";

    # tailscale0 only, like every other port this domain opens. A builder is
    # dialled by nothing except whatever fronts its reports.
    my.network.tailscale.allowedTCPPorts =
      optional cfg.ci.serveReports.enable cfg.ci.serveReports.listenPort;

    # `nix build` in a recipe talks to the daemon over its unix socket;
    # connect(2) on AF_UNIX needs a writable socket inode, and the broker's
    # ProtectSystem=strict makes /nix read-only. Targeted loosening only --
    # never enableHardening = false, and the node unit's confinement is not
    # touched (upstream defends it with a systemd-analyze threshold test).
    systemd.services.radicle-ci-broker.serviceConfig = {
      # See waitForNodeSocket above: `after`/`bindsTo` on a `simple` service
      # order against the EXEC, not against readiness, so the broker has to wait
      # for the node's control socket itself.
      ExecStartPre = [ "${waitForNodeSocket}" ];

      ReadWritePaths = [ "/nix/var/nix/daemon-socket" ];

      # WHY THE REPORTS SERVE AND THE LOGS DO NOT, without this.
      #
      # Upstream sets UMask=0066 on this unit, so everything it and its adapters
      # create is 0600 for files and 0711 for directories. The broker's own
      # report writer escapes that by calling set_permissions(0o644) explicitly
      # (radicle-ci-broker src/util.rs:151), which is why report_dir serves. The
      # native adapter never calls set_permissions anywhere in its tree, so a
      # run directory lands at 0711 and its log.html at 0600 -- owned by
      # radicle, and unreadable by nginx even though nginx is in that group.
      #
      # The symptom is a 403 from autoindex on a directory nginx can traverse
      # but not list, next to a report page that serves perfectly. Nothing
      # reports a permission error, because nothing tried to read the log.
      #
      # 0027 rather than 0066: group read, no other. The only member of group
      # radicle is nginx, added by this module for exactly this purpose.
      UMask = mkIf cfg.ci.serveReports.enable (mkForce "0027");

      # Upstream creates the report and adapter-log directories with
      # systemd-tmpfiles. That loses a race against impermanence: the bind
      # mount for /var/lib/radicle-ci is established AFTER tmpfiles has run,
      # so the directory tmpfiles made is hidden underneath it and the broker
      # starts logging "HTML report directory does not exist".
      #
      # StateDirectory/LogsDirectory are created by systemd as part of
      # starting the unit -- after mounts, every start -- so they are correct
      # on a persisted host and self-healing rather than reboot-dependent.
      # The adapter's per-run tree is named here for the same reason, plus
      # one of its own: the adapter creates its state directory only `if
      # !state.exists()`, so a directory that already exists keeps whatever
      # mode it was first made with -- 0711, from the unit's inherited
      # UMask -- and no later umask change can reach it. Naming the tree
      # here makes systemd apply StateDirectoryMode on every start, which
      # is what lets nginx list a run directory rather than 403 on it.
      StateDirectory = mkForce (
        [ "radicle-ci" "radicle-ci/reports" "radicle-ci/adapters" "radicle-ci/adapters/native" ]
        ++ mapAttrsToList (name: _: "radicle-ci/adapters/native/${name}") cfg.ci.adapters
      );
      StateDirectoryMode = mkIf cfg.ci.serveReports.enable "0750";
      LogsDirectory = mkForce [ "radicle-ci" "radicle-ci/adapters/native" ];

      # LET A BUILDER SANDBOX ITS BUILDS.
      #
      # nix builds in a sandbox, and that sandbox is the point of building on
      # nix at all -- it is never the thing to switch off. Creating one needs a
      # nested user namespace and the mount calls that follow it, and three
      # directives in upstream's `enableHardening` block each deny a different
      # part of that. Measured on this builder by the preflight in
      # radicle-release's own recipe, not reasoned about:
      #
      #   max_user_namespaces: 2147483647
      #   CapEff:              0000000000000000
      #   unshare: unshare failed: Operation not permitted
      #
      # EPERM rather than ENOSPC is the finding. A namespace LIMIT reports
      # ENOSPC, so an unlimited count sitting next to EPERM says something
      # REFUSES the call rather than having run out -- which also rules out
      # memory and CPU, the two things a container is usually short of. Not the
      # kernel, and not podman, whose profile allows clone, clone3 and unshare
      # with no argument mask. systemd's own filters, which the adapter inherits
      # because ci-broker.nix declares exactly one unit and the adapter is a
      # CHILD PROCESS of it, not a unit of its own:
      #
      #   RestrictNamespaces  seccomp-denies unshare(CLONE_NEWUSER) -- the EPERM
      #   SystemCallFilter    `~@privileged` subtracts pivot_root, chroot and
      #                       sethostname, which is what nix calls once it has
      #                       the namespace (systemd-analyze syscall-filter
      #                       @privileged lists exactly those)
      #   ProtectHostname     denies sethostname by itself, and is why every
      #                       earlier run died reporting `cannot set host name`
      #                       from inside an unrelated derivation
      #
      # This is still not `enableHardening = false`: LockPersonality,
      # MemoryDenyWriteExecute, RestrictRealtime, RestrictSUIDSGID,
      # RestrictAddressFamilies, ProtectClock, ProtectKernelModules,
      # ProtectKernelTunables and the rest stay as upstream set them. Only what
      # a sandbox cannot be built without is dropped.
      #
      # Scoped to a BUILDER inside a container: a seed runs no builds and keeps
      # all three, and on a host the unit's confinement IS the boundary so none
      # of it applies. The argument is ./container-confinement.nix's -- a
      # rootless container is already a user namespace with no SYS_ADMIN, a
      # bounded capability set and no-new-privileges. One boundary, not two.
      RestrictNamespaces = mkIf sandboxingBuilder (mkForce false);
      ProtectHostname = mkIf sandboxingBuilder (mkForce false);

      # PrivateUsers maps only the unit's own uid, so the nested namespace nix
      # wants has no root to map from.
      PrivateUsers = mkIf sandboxingBuilder (mkForce false);

      # Upstream's list minus `~@privileged`. `~@resources` stays: a build has
      # no business setting rlimits or re-nicing, and it was not what blocked.
      SystemCallFilter =
        mkIf sandboxingBuilder (mkForce [ "@system-service" "~@resources" ]);
    };
  };
}
