# Containers on darwin.
#
# The Linux side (./engines.nix) sets `virtualisation.podman` or
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
# Only docker is implemented here. Rootless podman's whole benefit on Linux is
# that there is no daemon and no root-equivalent group; inside a Colima VM the
# user is already root of a throwaway machine, so `podman machine` would buy
# nothing and cost a second VM stack. The podman option still EXISTS on darwin
# -- the engines are one option tree on both platforms -- so turning it on is an
# assertion below rather than a silent no-op.
{ activeUsers, config, lib, pkgs, ... }:

with lib;

let
  cfg = config.my.virtualisation.containers;

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
    # docker (in Colima) is the darwin engine; it comes on for a host whose
    # users want containers, like podman does on Linux.
    my.virtualisation.containers.docker.enable = mkDefault anyUserContainers;

    assertions = [
      {
        assertion = !cfg.podman.enable;
        message = ''
          my.virtualisation.containers.podman.enable is not implemented on darwin.
          macOS has no kernel to run containers on, so mynixos runs them in a
          Colima VM with the docker runtime (containers.docker, on by default
          here). Turn podman off on this host.
        '';
      }
    ];

    home-manager.users = mapAttrs
      (_name: userCfg:
        mkIf (wants userCfg && cfg.docker.enable) {
          home.packages = [
            runtime # colima — the Linux VM running the daemon
            pkgs.docker # client only on darwin; the daemon is in the VM
            pkgs.docker-compose
            pkgs.lazydocker # container TUI, as on the Linux side
          ];

          # `colima start` creates and selects a docker context, so DOCKER_HOST
          # is deliberately NOT set here — hardcoding it would fight the context
          # and break `docker context use`.

          launchd.agents.colima = mkIf cfg.darwin.colimaAutoStart {
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
