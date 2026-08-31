# my.dev.builderHost -- the BUILDER half of remote nix builds, declared here
# rather than in my/dev/development/options.nix so it exists on darwin ALONE.
#
# Reach is structural (CLAUDE.md): the implementation is a nix-darwin
# users.knownUsers account plus an /etc/nix/nix.custom.conf drop-in, neither of
# which NixOS would act on -- so on Linux this must not be settable at all
# rather than settable-and-inert. The client half is ./options-linux.nix
# (my.dev.remoteBuilders); the implementation is ./darwin.nix.
{ lib, ... }:

{
  # Only a `type` here: my/dev/development/options.nix owns the description
  # and default, and two declarations of those would collide. Submodule TYPES
  # merge, which is what adds this key to the existing my.dev option.
  dev = lib.mkOption {
    type = lib.types.submodule {
      options = {
        builderHost = lib.mkOption {
          description = ''
            Accept remote nix builds on this machine (darwin only -- the
            Linux hosts are clients). Creates a locked-down account whose ssh
            key is bound to `nix-daemon --stdio` by forced command, and
            trusts it in /etc/nix/nix.custom.conf (nix-darwin's nix.settings
            is unavailable on this fleet: nix.enable = false, the installer
            owns nix.conf). Ignored on NixOS.
          '';
          default = { };
          type = lib.types.submodule {
            options = {
              enable = lib.mkOption {
                type = lib.types.bool;
                default = false;
                description = "Accept remote nix builds via the builder account.";
              };
              user = lib.mkOption {
                type = lib.types.str;
                default = "nixremote";
                description = "Name of the builder account.";
              };
              uid = lib.mkOption {
                type = lib.types.int;
                default = 401;
                description = "Fixed uid for the builder account (nix-darwin knownUsers requires one; <500 keeps it off the login window). MUST stay outside 351-382: the darwin nix installer gives _nixbld1.._nixbld32 that range, macOS lets two records share a uid silently, and getpwuid() would then resolve the build user instead of this one -- making trusted-users match nondeterministically.";
              };
              authorizedKey = lib.mkOption {
                type = lib.types.str;
                example = "ssh-ed25519 AAAA…";
                description = "Public half of the clients' builder key.";
              };
            };
          };
        };
      };
    };
  };
}
