{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.my.system;

  # Where to look for the flake, in order. `my.system.flakeDir` is tried first so
  # a host can say outright where its configuration lives.
  #
  # The two fallbacks are NixOS conventions and neither exists on macOS, so a
  # darwin host must set my.system.flakeDir or these scripts find nothing.
  flakeDirCandidates =
    optional (cfg.flakeDir != null) cfg.flakeDir
    ++ [ "/etc/nixos" "$HOME/.flake" ];

  # Deliberately unquoted so $HOME expands.
  findFlakeDir = ''
    FLAKE_DIR=""
    for d in ${concatStringsSep " " flakeDirCandidates}; do
      if [ -f "$d/flake.nix" ]; then
        FLAKE_DIR="$d"
        break
      fi
    done
    if [ -z "$FLAKE_DIR" ]; then
      echo "Error: could not find flake.nix in any of: ${concatStringsSep ", " flakeDirCandidates}" >&2
      echo "Set my.system.flakeDir to point at your configuration." >&2
      exit 1
    fi
  '';

  # Prefer a local checkout over the locked input, for each entry in
  # my.system.localInputs whose path is actually there.
  #
  # Presence is tested at run time rather than baked in, so one configuration
  # serves the machine holding the checkout and a machine that has never seen it
  # -- the latter simply builds from flake.lock. That is what makes this safe to
  # state once in a profile every host shares.
  #
  # A checkout that is CLEAN and at exactly the locked revision is not
  # overridden at all: the override would produce the identical build while
  # making nix warn "not writing modified lock file" on every rebuild, and
  # making the announcement below false. The override -- and the announcement
  # -- fire only when the local checkout actually diverges from the lock.
  # Discovering an overridden build from a puzzling rebuild result is far
  # worse than reading one line.
  #
  # The locked revision is resolved by walking flake.lock's node graph from
  # the root along the "/"-separated input path, following `follows` entries
  # (which appear as arrays re-rooted at the top).
  lockedRevFor = ''
    locked_rev_for() {
      ${pkgs.jq}/bin/jq -r --arg path "$1" '
        def step($node; $rest):
          if ($rest | length) == 0 then $node
          else .nodes[$node].inputs[$rest[0]] as $next
            | if $next == null then empty
              elif ($next | type) == "array" then step(.root; $next + $rest[1:])
              else step($next; $rest[1:])
              end
          end;
        step(.root; $path | split("/")) as $node
        | .nodes[$node].locked.rev // empty
      ' "$FLAKE_DIR/flake.lock" 2>/dev/null
    }
  '';

  overrideInputs = ''
    ${lockedRevFor}
    OVERRIDES=()
    ${concatStringsSep "\n" (mapAttrsToList
      (name: path: ''
        if [ -d ${escapeShellArg path} ]; then
          _locked=$(locked_rev_for ${escapeShellArg name})
          _local=$(${pkgs.git}/bin/git -C ${escapeShellArg path} rev-parse HEAD 2>/dev/null || true)
          if [ -n "$_locked" ] && [ "$_locked" = "$_local" ] \
            && ${pkgs.git}/bin/git -C ${escapeShellArg path} diff-index --quiet HEAD -- 2>/dev/null; then
            echo "  local input: ${name} matches flake.lock (''${_locked:0:8}), no override" >&2
          else
            OVERRIDES+=(--override-input ${escapeShellArg name} ${escapeShellArg path})
            echo "  local input: ${name} -> ${path}" >&2
          fi
        fi
      '')
      cfg.localInputs)}
    if [ ''${#OVERRIDES[@]} -gt 0 ]; then
      echo "  (this build does NOT match flake.lock)" >&2
    fi
  '';

  # darwin-rebuild's actions are: edit | switch | activate | build | check |
  # changelog. There is NO `test`, so `nixos-rebuild test` maps to `check`, the
  # nearest equivalent -- it builds and runs the activation sanity checks. It is
  # not the same thing (check does not activate), so the script says so rather
  # than pretending.
  darwinAction = action: if action == "test" then "check" else action;

  # Root is required for actions that touch the running system, and only those.
  # darwin-rebuild enforces exactly `switch|activate|rollback|check`; `build`
  # deliberately needs no privileges, and sudo-ing it would leave root-owned
  # results. The NixOS side is the same idea.
  needsRootDarwin = a: elem a [ "switch" "activate" "rollback" "check" ];
  needsRootLinux = a: elem a [ "switch" "boot" "test" ];

  rebuildPreamble = action: ''
    if [[ "$OSTYPE" == "darwin"* ]]; then
      REBUILD_CMD="darwin-rebuild ${darwinAction action}"
      SUDO=${optionalString (needsRootDarwin (darwinAction action)) "sudo"}
      ${optionalString (action == "test") ''
      echo "note: darwin-rebuild has no 'test' action; running 'check' instead" >&2
      echo "      (builds and runs the activation sanity checks, but does not activate)" >&2
    ''}
    else
      REBUILD_CMD="nixos-rebuild ${action}"
      SUDO=${optionalString (needsRootLinux action) "sudo"}
    fi
  '';

  mkRebuildScript = { name, action, description }:
    pkgs.writeShellScriptBin name ''
      # ${description}
      ${rebuildPreamble action}
      ${findFlakeDir}

      echo "${description} from $FLAKE_DIR..."
      ${overrideInputs}
      cd "$FLAKE_DIR"
      $SUDO $REBUILD_CMD --flake .# ''${OVERRIDES[@]+"''${OVERRIDES[@]}"}
    '';
in
{
  config = mkIf cfg.enable {
    # System utility scripts available to all users
    environment.systemPackages = [
      # Update system flake inputs.
      #
      # `nix flake update` does not evaluate outputs, but it does re-FETCH every
      # input, so a host whose flake has an input it cannot resolve -- a path
      # input pointing somewhere that exists only on another machine -- fails
      # here exactly as it would under `nix flake check`. The way past it is to
      # name the inputs that can be fetched: `nix flake update <input>...`.
      (pkgs.writeShellScriptBin "update-system" ''
        ${findFlakeDir}

        echo "Updating flake inputs in $FLAKE_DIR..."
        cd "$FLAKE_DIR"
        nix flake update
      '')

      (mkRebuildScript {
        name = "rebuild-system";
        action = "switch";
        description = "Rebuilding system";
      })

      (mkRebuildScript {
        name = "test-system";
        action = "test";
        description = "Testing system configuration";
      })

      (mkRebuildScript {
        name = "build-system";
        action = "build";
        description = "Building system configuration";
      })
    ];
  };
}
