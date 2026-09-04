# passt, patched. pasta is podman's rootless network helper, and a NULL-flow
# dereference in its UDP error path (udp_sock_errs(), udp.c) segfaults it,
# taking every guest's only path to the network with it. The patch beside this
# file carries the full analysis.
#
# The patch guarantees "no crash". It does not guarantee "datapath restored" --
# a socket error that cannot be cleared now returns -1 into udp_sock_fwd()'s
# loop instead of killing the process. my.network.tailscale.liveness is what
# tells a working datapath from a spinning one.
#
# An overlay rather than `virtualisation.podman.package = pkgs.podman.override
# { passt = ...; }`: both reach libexec/podman/pasta, but the overlay cannot be
# bypassed by another module choosing a different podman, and it fixes
# pkgs.passt for anything else on the host. Safe because nothing on the Linux
# path sets `nixpkgs.pkgs`, so `nixpkgs.overlays` is honoured rather than
# warned about.
#
# No named argument: naming `pkgs` forces _module.args.pkgs from config.nixpkgs,
# which is the option this module writes to.
_:

{
  nixpkgs.overlays = [
    (_final: prev: {
      passt = prev.passt.overrideAttrs (o: {
        patches = (o.patches or [ ]) ++ [ ./udp-sock-errs-null-flow.patch ];
      });
    })
  ];
}
