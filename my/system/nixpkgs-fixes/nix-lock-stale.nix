# The Nix in devenv and nix-direnv, patched to tell a stale lock by what its path
# names.
#
# WHY THIS EXISTS
#
# PathLocks::lockPaths retries when the lock it holds has been deleted. Nix
# detects that from the file's size, because release is
#
#   tryUnlink(path); writeFull(fd, "d");
#
# and the result of the unlink is ignored. If the unlink fails, a non-empty file
# stays at the path. Every later locker opens that file, reads it as deleted and
# goes round again: no count, no backoff, no output at default verbosity, and
# SIGTERM does not stop it. The fetcher locks are keyed by input, so one such
# file hangs every evaluation that needs the input.
#
# With the patch, a file with no links is stale, an empty file is live, and a
# non-empty file is stale unless its path still names it. So a non-empty file at
# its path is an ordinary lock whose next release removes it. The link count alone
# is not enough: an NFS client renames a file that is still open rather than
# removing it, so a deleted lock keeps a link, and two holders would overlap.
#
# WHY THE DEVENV OVERRIDE LOOKS LIKE THIS
#
# devenv does not use pkgs.nix. It builds its own components from a pinned
# revision of cachix/nix, in a `let` inside its package, which no argument can
# reach directly. `overrideSource` is the one call it makes on the set it is
# given, so that call is wrapped to patch the source it receives. The components'
# own `appendPatches` is not usable here: it appends "+1" to their version, and
# the build script of devenv's Rust bindings fails to parse that.
#
# nix-direnv takes its fallback Nix as an argument, and gets the system's.
#
# DROP THIS FILE when devenv's pinned Nix stops testing `st.st_size` in
# src/libstore/unix/pathlocks.cc. The patch failing to apply is that signal.
final: prev: {
  devenv = prev.devenv.override {
    nixVersions = prev.nixVersions // {
      nixComponents_git = prev.nixVersions.nixComponents_git // {
        overrideSource = src:
          prev.nixVersions.nixComponents_git.overrideSource (prev.applyPatches {
            inherit src;
            patches = [ ./nix-lock-stale-reopen.patch ];
          });
      };
    };
  };

  nix-direnv = prev.nix-direnv.override {
    nix = final.nixVersions.latest.appendPatches [ ./nix-lock-stale-reopen.patch ];
  };
}
