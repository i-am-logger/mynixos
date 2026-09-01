# Opinionated default: darwin runs containers on Colima's docker runtime.
#
# `my.dev.containers.backend` is declared once, for both platforms, and its
# declared default is "podman" — the right answer on Linux, where rootless
# podman removes the root-equivalent `docker` group. macOS has no host kernel to
# be rootless on; containers run inside a Colima VM, and only the docker runtime
# is implemented there (see my/dev/containers/default.nix).
#
# So the platform default is flipped here rather than in the declaration: the
# option keeps one meaning and one type on both sides, a darwin host gets a
# working default instead of an assertion, and mkDefault means a host that
# genuinely wants to say otherwise still wins (and then hits the assertion,
# which is the honest outcome).
{ lib, ... }:

{
  config.my.dev.containers.backend = lib.mkDefault "docker";
}
