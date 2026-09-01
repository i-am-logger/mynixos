{ activeUsers, config, lib, pkgs, ... }:

with lib;

let
  cfg = config.my.dev;

  # Auto-enable dev tools when any user has dev.enable = true
  anyUserDev = any (userCfg: userCfg.dev.enable or false) (attrValues config.my.users);

  # Containers wanted if a user has dev enabled AND has not opted out.
  wantsContainers = u: (u.dev.enable or false) && (u.dev.containers.enable or true);
  anyUserContainers = any wantsContainers (attrValues config.my.users);

  # The accounts that actually run containers — not every active user. Only
  # these get subordinate id ranges.
  containerUsers = filterAttrs (_name: wantsContainers) (activeUsers config.my.users);

  inherit (cfg.containers) backend;
  usePodman = anyUserContainers && backend == "podman";
  useDocker = anyUserContainers && backend == "docker";
in
{
  config = mkMerge [
    # Set system flag
    { my.dev.enable = mkDefault anyUserDev; }

    # Base development groups
    (mkIf cfg.enable {
      users.users = mapAttrs
        (_name: _userCfg: {
          extraGroups = [ "disk" "dialout" ];
        })
        (activeUsers config.my.users);
    })

    # Podman (the default backend) — daemonless, rootless.
    #
    # No account is added to a container group. `podman` (like `docker`) is a
    # root-equivalent group: its socket hands out the ability to bind-mount / and
    # run as uid 0.
    #
    # Note what nixpkgs does regardless of anything set here: `mkIf cfg.enable`
    # creates `users.groups.podman` (podman/default.nix:329) AND socket-activates
    # the ROOTFUL podman socket with that SocketGroup (ibid:295-296). So enabling
    # podman at all leaves a joinable root-equivalent group and a live rootful
    # socket behind. Nothing here uses either -- every account talks to its own
    # rootless socket -- so the socket is switched off rather than left running
    # with no consumer, and the group is left empty and asserted so.
    (mkIf usePodman {
      virtualisation.containers.enable = true;

      # The rootful socket has no consumer on this host and is the one piece of
      # podman that IS root-equivalent. Turning it off is what makes the "no
      # daemon to grant access to" property true rather than merely nominal.
      systemd.sockets.podman.wantedBy = mkForce [ ];

      virtualisation.podman = {
        enable = true;
        # `docker` as an alias for the podman CLI, so docker-API tooling works
        # unchanged. It cannot coexist with virtualisation.docker — hence the
        # enum, not two booleans.
        #
        # dockerSocket.enable is deliberately NOT set. All it adds is a
        # /run/docker.sock symlink onto the ROOTFUL podman socket, whose
        # SocketGroup is `podman` — a group no account here joins, and whose
        # members could bind-mount / into a container and come back as root.
        # DOCKER_HOST below points docker-API clients at the user's own
        # rootless socket instead, so the symlink would be unreachable as well
        # as pointless.
        dockerCompat = true;
        # Container-to-container name resolution on the default network;
        # aardvark-dns is off unless this is set.
        defaultNetwork.settings.dns_enabled = true;
        # extraRuntimes is deliberately NOT set. crun -- podman's default OCI
        # runtime, and the one its rootless/cgroups-v2 paths are exercised
        # against -- is already unconditional in podman's helpersBin symlinkJoin
        # (pkgs/by-name/po/podman/package.nix:189); extraRuntimes is appended on
        # top of it. Since the option is a listOf with default [ runc ], setting
        # it REPLACES rather than appends, so `extraRuntimes = [ crun ]` would
        # add a duplicate crun and its only real effect would be dropping runc
        # as a `--runtime runc` fallback. Nothing here wants that.
      };

      # Point docker-API clients at the user's OWN rootless socket rather than
      # the root-owned /run/docker.sock symlink, which only the podman group can
      # reach. Mirrors virtualisation.docker.rootless.setSocketVariable, which
      # has no podman counterpart.
      environment.extraInit = ''
        if [ -z "$DOCKER_HOST" -a -n "$XDG_RUNTIME_DIR" ]; then
          export DOCKER_HOST="unix://$XDG_RUNTIME_DIR/podman/podman.sock"
        fi
      '';

      # podman itself comes from the module. crun is listed here only so the
      # binary is on PATH for direct use -- podman finds its own copy in
      # helpersBin regardless.
      environment.systemPackages = with pkgs; [
        crun
        podman-compose
        podman-tui
        minikube
        lazydocker
      ];
    })

    # Docker — the opt-out backend, still rootless.
    #
    # Also no `docker` group: rootless dockerd runs as the user and
    # setSocketVariable points DOCKER_HOST at the per-user socket, so group
    # membership would only re-add the root-equivalent path it replaced.
    (mkIf useDocker {
      virtualisation.docker = {
        enable = true;
        enableOnBoot = false;
        rootless = {
          enable = true;
          setSocketVariable = true;
        };
      };

      environment.systemPackages = with pkgs; [
        docker-compose
        minikube
        runc
        lazydocker
      ];
    })

    # Subordinate id ranges — a requirement of BOTH backends, so the guard sits
    # outside either branch. Rootless podman and rootless dockerd both map
    # container uids into a SUBORDINATE range owned by the user; without a
    # /etc/subuid + /etc/subgid entry the first `run` fails with an opaque
    # "cannot find UID/GID for user" mapping error, and newuidmap has nothing to
    # work from.
    #
    # Nothing is written to users.users here, on purpose. nixpkgs already sets
    # `autoSubUidGidRange = mkDefault true`, but GATED on the account being a
    # normal user with NO explicit subUidRanges/subGidRanges. An ungated
    # mkDefault from this module would therefore be uncontested on exactly the
    # hosts that DID set explicit ranges, switching auto-allocation back on and
    # appending a second range on top of the deliberate one. So the requirement
    # is checked rather than forced, and it is checked at EVALUATION time
    # instead of on the user's first container run.
    (mkIf anyUserContainers {
      assertions = mapAttrsToList
        # AND, not OR, on the explicit ranges: nixpkgs turns its auto-allocation
        # default off when EITHER list is set (users-groups.nix:496 gates on
        # both being empty). An account with only subUidRanges therefore gets an
        # /etc/subuid entry and no /etc/subgid one, and fails in newgidmap at
        # first `podman run` -- exactly what this assertion exists to catch, so
        # an OR here would let it straight through.
        (name: _userCfg: {
          assertion =
            let u = config.users.users.${name}; in
            u.autoSubUidGidRange || (u.subUidRanges != [ ] && u.subGidRanges != [ ]);
          message = ''
            my.users.${name} runs rootless containers (my.dev.containers.backend
            = "${backend}") but has no subordinate uid/gid range:
            users.users.${name}.autoSubUidGidRange is off and no
            subUidRanges/subGidRanges are set. `${backend} run` would fail at
            runtime with an opaque uid-mapping error. Leave autoSubUidGidRange
            alone, or give the account explicit subUidRanges and subGidRanges.
          '';
        })
        containerUsers;
    })

    # Binfmt emulation (dev feature)
    (mkIf cfg.enable {
      boot.binfmt = {
        emulatedSystems = [ "aarch64-linux" ];

        # AppImage support
        registrations.appimage = {
          wrapInterpreterInShell = false;
          interpreter = "${pkgs.appimage-run}/bin/appimage-run";
          recognitionType = "magic";
          offset = 0;
          mask = ''\xff\xff\xff\xff\x00\x00\x00\x00\xff\xff\xff'';
          magicOrExtension = ''\x7fELF....AI\x02'';
        };
      };
    })

    # Persistence configuration
    (mkIf cfg.enable {
      my.system.persistence.features = {
        # /var/lib/docker is the dockerd graph root and exists only under that
        # backend; carrying it on a podman host would persist an empty directory
        # and imply a runtime that is not installed.
        systemDirectories = [
          "/var/lib/containers"
        ] ++ optional useDocker "/var/lib/docker";

        # .local/share/containers is where ROOTLESS podman keeps its storage,
        # so on an impermanent host it is the difference between keeping images
        # and re-pulling them every boot. `.docker` is not here: it is docker's
        # client config, and belongs to the docker backend alone.
        userDirectories = [
          ".local/share/containers"
          ".npm"
          ".cargo"
          ".rustup"
          ".gradle"
          ".m2"
        ] ++ optionals useDocker [
          ".docker"
          ".local/share/docker"
        ];
      };
    })
  ];
}
