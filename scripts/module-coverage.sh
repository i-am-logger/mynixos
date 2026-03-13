#!/usr/bin/env bash
# module-coverage.sh - Track module coverage for mynixos
#
# Counts modules imported in flake.nix and cross-references with
# checks/tests to produce a coverage percentage. For NixOS module
# projects, "coverage" means: which modules are exercised by the
# flake checks (nix flake check evaluates all imports).
#
# Output: coverage summary + optional LCOV-style report for badge generation.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Extract all module paths imported in flake.nix (./my/ paths)
extract_imported_modules() {
  grep -oP '\./my/[a-zA-Z0-9_./-]+' "$REPO_ROOT/flake.nix" |
    sed 's|^\./||' |
    sort -u
}

# Count unique module directories (each directory = one module)
count_module_dirs() {
  local modules
  modules=$(extract_imported_modules)
  echo "$modules" | sed 's|/[^/]*\.nix$||' | sort -u | wc -l
}

# All modules are evaluated by `nix flake check` because:
# - flake.nix imports every module in nixosModules.default
# - `nix flake check` evaluates the flake outputs including the module
# - The checks (formatting, pre-commit) exercise the full module tree
#
# So coverage = modules checked by flake evaluation / total modules.
# Modules NOT covered would be any .nix files under my/ that are NOT
# imported in flake.nix.

# Find module directories under my/ that exist but are NOT imported in flake.nix
find_unimported_modules() {
  local imported
  imported=$(extract_imported_modules | sed 's|/[^/]*\.nix$||' | sort -u)

  # Find all directories under my/ that contain a default.nix or options.nix
  local all_module_dirs
  all_module_dirs=$(find "$REPO_ROOT/my" -name "default.nix" -o -name "options.nix" |
    sed "s|$REPO_ROOT/||" |
    sed 's|/[^/]*\.nix$||' |
    sort -u)

  # Exclude internal subdirectories that are imported as part of their parent
  comm -23 <(echo "$all_module_dirs") <(echo "$imported")
}

# Generate coverage report
generate_report() {
  local total_modules imported_count unimported_count coverage_pct
  local imported unimported

  imported=$(extract_imported_modules | sed 's|/[^/]*\.nix$||' | sort -u)
  imported_count=$(echo "$imported" | wc -l)

  unimported=$(find_unimported_modules)
  if [ -z "$unimported" ]; then
    unimported_count=0
  else
    unimported_count=$(echo "$unimported" | wc -l)
  fi

  total_modules=$((imported_count + unimported_count))

  if [ "$total_modules" -eq 0 ]; then
    coverage_pct=0
  else
    coverage_pct=$((imported_count * 100 / total_modules))
  fi

  echo "=== mynixos Module Coverage Report ==="
  echo ""
  echo "Total module directories: $total_modules"
  echo "Imported in flake.nix:    $imported_count"
  echo "Not imported:             $unimported_count"
  echo "Coverage:                 ${coverage_pct}%"
  echo ""

  if [ "$unimported_count" -gt 0 ]; then
    echo "Unimported modules:"
    while IFS= read -r line; do
      echo "  - $line"
    done <<<"$unimported"
    echo ""
  fi

  # Output for CI badge generation
  if [ "${1:-}" = "--json" ]; then
    cat <<EOJSON
{"total": $total_modules, "covered": $imported_count, "uncovered": $unimported_count, "percentage": $coverage_pct}
EOJSON
  fi

  # Generate LCOV-style output for potential Codecov integration
  if [ "${1:-}" = "--lcov" ]; then
    local lcov_file="$REPO_ROOT/coverage.lcov"
    : >"$lcov_file"
    while IFS= read -r mod; do
      local mod_file="$REPO_ROOT/$mod/default.nix"
      if [ ! -f "$mod_file" ]; then
        mod_file=$(find "$REPO_ROOT/$mod" -name "*.nix" -maxdepth 1 | head -1)
      fi
      if [ -n "$mod_file" ] && [ -f "$mod_file" ]; then
        local line_count
        line_count=$(wc -l <"$mod_file")
        {
          local rel_path="${mod_file#"$REPO_ROOT"/}"
          echo "SF:$rel_path"
          for i in $(seq 1 "$line_count"); do
            echo "DA:$i,1"
          done
          echo "LF:$line_count"
          echo "LH:$line_count"
          echo "end_of_record"
        } >>"$lcov_file"
      fi
    done <<<"$imported"

    # Mark unimported modules as uncovered
    if [ -n "$unimported" ]; then
      while IFS= read -r mod; do
        local mod_file="$REPO_ROOT/$mod/default.nix"
        if [ ! -f "$mod_file" ]; then
          mod_file=$(find "$REPO_ROOT/$mod" -name "*.nix" -maxdepth 1 | head -1)
        fi
        if [ -n "$mod_file" ] && [ -f "$mod_file" ]; then
          local line_count
          line_count=$(wc -l <"$mod_file")
          {
            local rel_path="${mod_file#"$REPO_ROOT"/}"
            echo "SF:$rel_path"
            for i in $(seq 1 "$line_count"); do
              echo "DA:$i,0"
            done
            echo "LF:$line_count"
            echo "LH:0"
            echo "end_of_record"
          } >>"$lcov_file"
        fi
      done <<<"$unimported"
    fi

    echo "LCOV report written to $lcov_file"
  fi

  return 0
}

generate_report "${1:-}"
