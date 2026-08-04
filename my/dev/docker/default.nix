# Docker on darwin.
#
# The NixOS side (my/dev/development) sets `virtualisation.docker`, which does
# not exist on macOS — there is no Linux kernel to run containers on. macOS needs
# a Linux VM, and the daemon lives inside it.
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
# Reads the same `dev.docker.enable` option the NixOS side uses, so a host
# turns it on identically on either platform.
{ activeUsers, config, lib, pkgs, ... }:

with lib;

let
  cfg = config.my.dev.docker;

  runtime = pkgs.colima;

  # `or true` matches my/dev/development on the NixOS side: docker.enable is
  # declared with default = true, so a user who turns dev on gets docker unless
  # they say otherwise. The fallback is unreachable while that default stands --
  # it exists so both platforms read the same if it ever stops standing.
  wants = userCfg: (userCfg.dev.enable or false) && (userCfg.dev.docker.enable or true);
in
{
  config = {
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
