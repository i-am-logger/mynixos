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
        (_: adapter: {
          # listOf merge CONCATENATES with upstream's unconditional base set
          # (bash, coreutils, git, ...); module-eval asserts nix survives the
          # merge so an upstream mkForce would fail CI here, not on a host.
          runtimePackages = [ pkgs.nix radicle-ci-build ] ++ adapter.extraRuntimePackages;
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
        locations."/" = {
          alias = "${config.services.radicle.ci.broker.settings.report_dir}/";
          # autoindex because a run is named after its id: without a listing
          # there is no way to reach one without already knowing it.
          extraConfig = "autoindex on;";
        };
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

      # Upstream creates the report and adapter-log directories with
      # systemd-tmpfiles. That loses a race against impermanence: the bind
      # mount for /var/lib/radicle-ci is established AFTER tmpfiles has run,
      # so the directory tmpfiles made is hidden underneath it and the broker
      # starts logging "HTML report directory does not exist".
      #
      # StateDirectory/LogsDirectory are created by systemd as part of
      # starting the unit -- after mounts, every start -- so they are correct
      # on a persisted host and self-healing rather than reboot-dependent.
      StateDirectory = mkForce [ "radicle-ci" "radicle-ci/reports" ];
      LogsDirectory = mkForce [ "radicle-ci" "radicle-ci/adapters/native" ];
    };
  };
}
