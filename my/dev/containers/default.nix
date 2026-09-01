# Containers on darwin.
#
# The NixOS side (my/dev/development) sets `virtualisation.podman` or
# `virtualisation.docker`, neither of which exists on macOS — there is no Linux
# kernel to run containers on. macOS needs a Linux VM, and the runtime lives
# inside it.
#
# This uses Colima (Lima + containerd/dockerd). The `docker` CLI here is the
# client only; it talks to the daemon inside the VM over a socket, and Colima
# registers a `colima` docker context on first `colima start`.
#
# Not Docker Desktop: it is unfree, absent from nixpkgs and self-updating, so it
# cannot be managed declaratively at all.
#
# Not apple/container (in nixpkgs, aarch64-darwin only), even though its
# one-lightweight-VM-per-container model isolates better and starts faster: it
# has its own CLI rather than a docker-compatible one, and no compose
# equivalent. Colima keeps `docker` and `docker-compose` behaving the same way
# on both platforms, which is worth more here than the isolation is.
#
# Only `backend = "docker"` is implemented here. Rootless podman's whole benefit
# on Linux is that there is no daemon and no root-equivalent group; inside a
# Colima VM the user is already root of a throwaway machine, so `podman machine`
# would buy nothing and cost a second VM stack. The option still EXISTS on
# darwin — it is one option on both platforms — so the mismatch is an assertion
# below rather than a silent no-op, and mynixos-darwin.nix makes "docker" the
# default here so the fleet does not trip it by accident.
{ activeUsers, config, lib, pkgs, ... }:

with lib;

let
  cfg = config.my.dev.containers;

  runtime = pkgs.colima;

  # `or true` matches my/dev/development on the NixOS side: containers.enable is
  # declared with default = true, so a user who turns dev on gets containers
  # unless they say otherwise. The fallback is unreachable while that default
  # stands -- it exists so both platforms read the same if it ever stops
  # standing.
  wants = userCfg: (userCfg.dev.enable or false) && (userCfg.dev.containers.enable or true);

  anyUserContainers = any wants (attrValues config.my.users);
in
{
  config = {
    assertions = [
      {
        assertion = anyUserContainers -> cfg.backend == "docker";
        message = ''
          my.dev.containers.backend = "${cfg.backend}" is not implemented on darwin.
          macOS has no kernel to run containers on, so mynixos runs them in a
          Colima VM with the docker runtime. Set my.dev.containers.backend =
          "docker" on this host (my/dev/containers/mynixos-darwin.nix already
          does so by default), or turn containers off for its users.
        '';
      }
    ];

    home-manager.users = mapAttrs
      (_name: userCfg:
        mkIf (wants userCfg) {
          home.packages = [
            runtime # colima — the Linux VM running the daemon
            pkgs.docker # client only on darwin; the daemon is in the VM
            pkgs.docker-compose
            pkgs.lazydocker # container TUI, as on the Linux side
          ];

          # `colima start` creates and selects a docker context, so DOCKER_HOST
          # is deliberately NOT set here — hardcoding it would fight the context
          # and break `docker context use`.

          launchd.agents.colima = mkIf cfg.autoStart {
            enable = true;
            config = {
              Label = "org.mynixos.colima";
              ProgramArguments = [ "${runtime}/bin/colima" "start" ];
              RunAtLoad = true;
              KeepAlive = false;
              StandardErrorPath = "/tmp/colima.log";
            };
          };
        })
      (activeUsers config.my.users);
  };
}
