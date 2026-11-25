# my.virtualisation — the engines that isolate things on THIS host, and the
# workloads it runs on them. (Services this host provides to the fleet, such as
# RKE2 cluster membership, are my.infra; RKE2 brings its own containerd, but
# everything you configure for it is membership.)
#
#   containers.{podman,docker}  engines, both platforms     (this file)
#   containers.darwin           Colima settings, darwin     (./containers/darwin-options.nix)
#   containers.guests           systems/images it runs      (./containers/guests-options.nix, Linux)
#   incus                       system containers + VMs     (./incus/options.nix, Linux)
#   vms                         libvirt, quickemu, machines (./vms/options.nix, Linux)
#
# PLATFORM-ONLY SETTINGS of a feature that exists on both platforms go under a
# `.darwin` / `.linux` key of that feature, declared only by that platform.
# Whole features that exist on one platform only are simply declared there.
{ lib, ... }:

{
  virtualisation = lib.mkOption {
    description = "Container and VM engines on this host, and what it runs on them";
    default = { };
    type = lib.types.submodule {
      options.containers = lib.mkOption {
        description = "Container engines, and (on Linux) the guests run on them";
        default = { };
        type = lib.types.submodule {
          options = {
            # Engines are independent booleans: a host may run both. The one
            # real collision -- both want to own the `docker` command and
            # /run/docker.sock -- is settled, not configured: with docker on,
            # `docker` is docker; otherwise podman's dockerCompat provides it.
            podman.enable = lib.mkOption {
              type = lib.types.bool;
              default = false;
              defaultText = lib.literalExpression "true on Linux when any user has dev.containers";
              description = ''
                Rootless podman: daemonless, no root-equivalent group, the
                rootful socket switched off. On by default on Linux for hosts
                whose users want containers. Not implemented on darwin
                (asserted).
              '';
            };

            docker.enable = lib.mkOption {
              type = lib.types.bool;
              default = false;
              defaultText = lib.literalExpression "true on darwin when any user has dev.containers";
              description = ''
                Docker. On Linux: rootless dockerd, beside podman if that is on
                too (then `docker` runs real docker). On darwin: the docker CLI
                against a Colima VM, the default there.
              '';
            };
          };
        };
      };
    };
  };
}
