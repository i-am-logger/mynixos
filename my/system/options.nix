{ lib, ... }:

{
  system = lib.mkOption {
    description = "System-level configuration";
    default = { };
    type = lib.types.submodule {
      options = {
        hostname = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = "System hostname (if null, uses my.hostname for backwards compatibility)";
        };



        flakeDir = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          example = "/Users/logger/Code/flake";
          description = ''
            Where the rebuild-system / test-system / build-system / update-system
            scripts should look for this host's flake.

            When null they fall back to /etc/nixos then ~/.flake, which are NixOS
            conventions -- neither exists on macOS, so a darwin host must set this
            or the scripts cannot find anything to build.

            Scope is deliberately narrow: this is a RUNTIME lookup path for those
            scripts, not a declaration of where the configuration lives.
            my/storage/impermanence hardcodes /etc/nixos on purpose and is not
            wired to this option -- coupling them would let a scripts-convenience
            setting change what a tmpfs-root host persists.
          '';
        };

        localInputs = lib.mkOption {
          type = lib.types.attrsOf lib.types.str;
          default = { };
          example = { mynixos = "/Users/logger/Code/mynixos"; };
          description = ''
            Local checkouts the rebuild scripts should prefer over the locked
            inputs, as input name -> path. Each one that is PRESENT at run time
            becomes `--override-input <name> <path>`.

            Existence is checked when the script runs, not when it is built, so
            one configuration serves both the machine that has the checkout and
            the machine that does not -- the latter silently falls back to
            flake.lock. That is what makes this safe to state in a profile
            shared by every host.

            The alternative it replaces is locking an input to a local path,
            which pins every OTHER host to a directory that exists on one
            machine. Here the lock keeps naming a real revision and only the
            local build departs from it.

            A build that overrides is a build that does not match flake.lock, so
            the scripts say which inputs they replaced. Type is str rather than
            path: a path would be copied into the store at evaluation time,
            which would defeat the point of pointing at a working tree.
          '';
        };

        update = lib.mkOption {
          description = "How `rebuild-system update` refreshes this host before building";
          default = { };
          type = lib.types.submodule {
            options = {
              scripts = lib.mkOption {
                type = lib.types.listOf lib.types.str;
                default = [ ];
                example = [ "scripts/update-claude-code.sh" ];
                description = ''
                  Scripts that re-pin this host's overlays, run in order after the
                  flake inputs are updated and before anything is built. Paths are
                  relative to the flake directory.

                  Listed one by one rather than discovered by glob. A glob over
                  something like scripts/update-*.sh reads as the obvious
                  convention right up until it matches a script that was never
                  meant for it -- update-master-from-old-commit.sh, say, whose
                  work is `git branch -f master`. Naming them is the difference
                  between a list that is audited and a directory that is trusted.

                  Each is expected to be idempotent and to exit 0 when there is
                  nothing to do, because it runs on every update.
                '';
              };

              inputs = lib.mkOption {
                type = lib.types.nullOr (lib.types.listOf lib.types.str);
                default = null;
                example = [ "mynixos" ];
                description = ''
                  Flake inputs to update, or null to work them out from
                  flake.lock.

                  Deriving them is the default because the thing that must be
                  excluded is discoverable: `nix flake update` re-FETCHES every
                  input even though it evaluates no outputs, so an input locked
                  to a path or a git+file:// URL that exists on one machine fails
                  the update on every other. Those are exactly the entries the
                  lock marks type "path" or type "git" with a file:// URL, so
                  they are skipped without anyone maintaining a list that rots
                  the next time an input is added.

                  Name them explicitly only to update FEWER than that.
                '';
              };
            };
          };
        };

        enable = lib.mkEnableOption "core system utilities (console, nix, boot configuration, plymouth)";




        allowedUnfreePackages = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          description = "List of unfree package names to allow. Modules append to this list and a single predicate is built centrally.";
        };

      };
    };
  };
}
