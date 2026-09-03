# `system.build.image`: the role system, streamed as an OCI image.
#
# Imported only by platforms/oci.nix, so it exists exactly where it makes
# sense -- the same rule that keeps my.security off darwin.
#
# streamLayeredImage rather than buildImage or the docker-container profile's
# own `system.build.tarball`, for one reason each:
#
#   * LAYERED, because the ~460 store paths a "it is a machine" role costs are
#     near-identical across every role. Layered images make them shared
#     content-addressed layers, so the first role costs its full closure and
#     each additional role costs only its marginal paths.
#   * STREAM, because the output is a script that writes the tarball to stdout
#     rather than a multi-GB tarball sitting in the nix store next to the
#     closure it was built from. `virtualisation.oci-containers` consumes
#     exactly this through its `imageStream` option -- no registry, and the
#     image is never materialised twice.
#
# Size is NOT optimised here, deliberately. Correctness first; shrinking the
# closure is separate work with its own gates.
{ config, pkgs, ... }:

let
  inherit (config.system.build) toplevel;

  # What `register-nix-paths` (from nixpkgs' docker-container profile) loads at
  # boot. Without it the image has a /nix/store full of paths that nix itself
  # does not know about, so every `nix build` inside a builder role would
  # re-fetch or rebuild what is already there.
  #
  # closureInfo's own store path is referenced from extraCommands only, which
  # runs at image-BUILD time -- so the registration file's contents land in the
  # image while the derivation that produced them does not.
  registration = pkgs.closureInfo { rootPaths = [ toplevel ]; };
in
{
  imports = [ ./options.nix ];

  config = {
    system.build.image = pkgs.dockerTools.streamLayeredImage {
      name = config.networking.hostName;

      # The tag is the identity's, not the build's. A role image is only ever
      # as trustworthy as the key it was built for, and the reference fleet in
      # roles/radicle is built for keys whose private halves were destroyed --
      # so tagging both `latest` would let a reference image silently occupy the
      # tag a real deployment's image lands on, in a runtime where the two are
      # otherwise indistinguishable. `my.system.ociImage.tag` is what a real
      # deployment sets; the reference fleet leaves it at its default.
      inherit (config.my.system.ociImage) tag;

      # `contents` stays EMPTY on purpose. Adding the toplevel here would
      # symlink-join it into the image root, putting a read-only store symlink
      # at /etc -- exactly the path stage-2 activation has to own. The store
      # closure still arrives: streamLayeredImage computes it from the config
      # JSON too, and Cmd below names the toplevel.
      contents = [ ];

      config = {
        # systemd as PID 1. `${toplevel}/init` and not the /init symlink
        # created below, because this string is what carries the closure.
        Cmd = [ "${toplevel}/init" ];
        Env = [
          "PATH=/run/current-system/sw/bin:/run/current-system/sw/sbin"
          "container=podman"
        ];
        # systemd treats SIGRTMIN+3 as "shut down cleanly". The default SIGTERM
        # is what PID 1 uses for its own re-exec, so a plain `podman stop` would
        # sit through the timeout and then be killed.
        StopSignal = "SIGRTMIN+3";
      };

      # The docker-container profile's extraCommands does the same `rm etc`
      # dance for its tarball; with `contents = [ ]` there is nothing to remove,
      # only the mount points systemd expects to already exist.
      extraCommands = ''
        mkdir -p proc sys dev run tmp var/tmp etc
        chmod 1777 tmp var/tmp
        ln -s ${toplevel}/init init
        cp ${registration}/registration nix-path-registration
      '';
    };
  };
}
