#!/usr/bin/env bash
# build-packages.sh - build every packages/* against mynixos's locked nixpkgs
#
# `nix flake check` and host evaluation only instantiate derivations; they
# never build them, so a package that stops compiling on a new nixpkgs (qobine
# on d5cc6833: libsqlite3-sys stopped bundling SQLite) passes both. This builds
# them. Unchanged packages come from the store, so a rerun is cheap.
#
#   scripts/build-packages.sh [system]   (default: x86_64-linux)
#
# A package whose meta.platforms excludes the system is skipped, not failed.
# Exit 0 only when every buildable package built.
set -u
system=${1:-x86_64-linux}
root=$(cd "$(dirname "$0")/.." && pwd)
fail=0
built=0
for dir in "$root"/packages/*/; do
  dir=${dir%/}
  name=$(basename "$dir")
  # Not every directory is a package: packages/cava holds only a patch.
  [ -f "$dir/default.nix" ] || continue
  expr="let
    pkgs = import (builtins.getFlake \"$root\").inputs.nixpkgs {
      system = \"$system\";
      config.allowUnfree = true;
    };
    drv = pkgs.callPackage $dir { };
  in if pkgs.lib.meta.availableOn pkgs.stdenv.hostPlatform drv then drv else null"
  # stdout alone: nix prints warnings on stderr, and they must not be read as
  # the answer.
  if ! avail=$(nix eval --impure --expr "($expr) != null" 2>/dev/null); then
    echo "FAIL  $name (evaluation)"
    nix eval --impure --expr "($expr) != null" 2>&1 | grep -E 'error:' | tail -2 | sed 's/^/      /'
    fail=1
    continue
  fi
  if [ "$avail" != "true" ]; then
    echo "skip  $name (not for $system)"
    continue
  fi
  if out=$(nix build --no-link --impure --expr "$expr" 2>&1); then
    echo "ok    $name"
    built=$((built + 1))
  else
    echo "FAIL  $name"
    printf '%s\n' "$out" | grep -E 'error|cannot find' | tail -3 | sed 's/^/      /'
    fail=1
  fi
done
# A run that built nothing checked nothing: say so rather than pass.
if [ "$built" -eq 0 ]; then
  echo "FAIL  no package built for $system"
  fail=1
fi
exit $fail
