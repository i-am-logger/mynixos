# my.dev.remoteBuilders -- the CLIENT half of remote nix builds, declared here
# rather than in my/dev/development/options.nix so it exists on Linux ALONE.
#
# Reach is structural (CLAUDE.md): nix.buildMachines is a NixOS option, so a
# darwin host setting this could only be a silent no-op. Declaring it only
# where platforms/linux.nix can see it turns that into the module system's own
# "option does not exist" error. The mirror-image half is ./options-darwin.nix
# (my.dev.builderHost), and the implementation is ./default.nix.
#
# `types.submodule` declarations merge, so this ADDS a key to the my.dev
# submodule declared in my/dev/development/options.nix.
{ lib, ... }:

{
  # Only a `type` here: my/dev/development/options.nix owns the description
  # and default, and two declarations of those would collide. Submodule TYPES
  # merge, which is what adds this key to the existing my.dev option.
  dev = lib.mkOption {
    type = lib.types.submodule {
      options = {
        remoteBuilders = lib.mkOption {
          default = [ ];
          description = ''
            Remote nix builders this machine dispatches to (Linux only --
            darwin fleet members are builders, not clients). Each entry
            becomes a nix.buildMachines record plus an ssh Host block with a
            fast ConnectTimeout, so an asleep builder fails loudly in seconds
            instead of wedging builds.
          '';
          type = lib.types.listOf (lib.types.submodule {
            options = {
              hostName = lib.mkOption {
                type = lib.types.str;
                example = "aether5d-dev.tailnet.ts.net";
                description = "Builder address (tailnet MagicDNS name).";
              };
              systems = lib.mkOption {
                type = lib.types.listOf lib.types.str;
                example = [ "aarch64-darwin" ];
                description = "Systems this builder provides.";
              };
              sshUser = lib.mkOption {
                type = lib.types.str;
                default = "nixremote";
                description = "Account on the builder (see my.dev.builderHost).";
              };
              sshKeySecret = lib.mkOption {
                type = lib.types.str;
                default = "nix/remote-builder-key";
                description = ''
                  sops secret name of the passphrase-less ed25519 private key
                  the nix daemon (root) uses to reach the builder.
                '';
              };
              publicHostKey = lib.mkOption {
                type = lib.types.str;
                description = ''
                  The builder's base64-encoded host key
                  (`base64 -w0 /etc/ssh/ssh_host_ed25519_key.pub`) -- pinned,
                  no trust-on-first-use.
                '';
              };
              maxJobs = lib.mkOption {
                type = lib.types.int;
                default = 4;
                description = "Concurrent jobs on the builder.";
              };
              speedFactor = lib.mkOption {
                type = lib.types.int;
                default = 2;
                description = "Relative speed weighting.";
              };
              supportedFeatures = lib.mkOption {
                type = lib.types.listOf lib.types.str;
                default = [ "big-parallel" ];
                description = "Features advertised for scheduling.";
              };
            };
          });
        };
      };
    };
  };
}
