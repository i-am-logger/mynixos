# `system.build.image`: this machine, taken as an OCI container image.
#
# An OUTPUT of an ordinary NixOS configuration, not a kind of configuration.
# Copied deliberately from nixos/modules/virtualisation/build-vm.nix:13:
#
#     vmVariant = extendModules { modules = [ ./qemu-vm.nix ]; };
#     system.build.vm = mkDefault config.virtualisation.vmVariant.system.build.vm;
#
# and note that qemu-vm.nix is pointedly NOT in nixpkgs' module list. The VM
# shape exists only inside the variant, so nothing in the base system knows it
# might be run as one. platforms/oci-variant.nix has the same standing
# here: nothing knows a container is possible until someone reads
# `system.build.image`.
#
# The variant is applied on top of the Linux system this machine already is, so
# every option it sets is already declared, and a container is expressed by
# what the variant overrides rather than constructed as a platform of its own.
{ config, lib, extendModules, ... }:

let
  ociVariant = extendModules {
    modules = [ ../../../platforms/oci-variant.nix ];
  };
in
{
  imports = [ ./options.nix ];

  options = {
    virtualisation.ociVariant = lib.mkOption {
      description = ''
        Configuration added on top of this machine to produce its container
        image. Set anything here that should be true of the image and false of
        the machine itself.
      '';
      inherit (ociVariant) type;
      default = { };
      visible = "shallow";
    };
  };

  config = {
    system.build.image = lib.mkDefault config.virtualisation.ociVariant.system.build.image;

    # A variant of a variant is a container image of a container image, which is
    # nothing. build-vm.nix:62-69 guards its own the same way and for the same
    # reason: unguarded, the recursion surfaces as an evaluation that never
    # terminates rather than as an error naming what went wrong.
    virtualisation.ociVariant = {
      options.virtualisation.ociVariant = lib.mkOption {
        apply = _: throw "virtualisation.ociVariant.virtualisation.ociVariant is not supported";
      };
    };
  };

  # uses extendModules
  meta.buildDocsInSandbox = false;
}
