{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.my.system;

  # Shared flake discovery snippet used by all system scripts.
  # Sets FLAKE_DIR to the first directory containing flake.nix.
  findFlakeDir = ''
    if [ -d "/etc/nixos" ] && [ -f "/etc/nixos/flake.nix" ]; then
      FLAKE_DIR="/etc/nixos"
    elif [ -d "$HOME/.flake" ] && [ -f "$HOME/.flake/flake.nix" ]; then
      FLAKE_DIR="$HOME/.flake"
    else
      echo "Error: Could not find flake.nix in /etc/nixos or ~/.flake"
      exit 1
    fi
  '';

  # Detect the appropriate rebuild command based on platform.
  detectRebuildCmd = action: ''
    if [[ "$OSTYPE" == "darwin"* ]]; then
      REBUILD_CMD="darwin-rebuild ${action} --flake"
    else
      REBUILD_CMD="nixos-rebuild ${action} --flake"
    fi
  '';
in
{
  config = mkIf cfg.enable {
    # System utility scripts available to all users
    environment.systemPackages = [
      # Update system flake inputs
      (pkgs.writeScriptBin "update-system" ''
        #!/usr/bin/env bash
        # Update flake inputs for the system configuration

        ${findFlakeDir}

        echo "Updating flake inputs in $FLAKE_DIR..."
        cd "$FLAKE_DIR"
        nix flake update
      '')

      # Rebuild system configuration
      (pkgs.writeScriptBin "rebuild-system" ''
        #!/usr/bin/env bash
        # Rebuild and switch to new system configuration

        ${detectRebuildCmd "switch"}
        ${findFlakeDir}

        echo "Rebuilding system from $FLAKE_DIR..."
        cd "$FLAKE_DIR"
        sudo $REBUILD_CMD .#
      '')

      # Test system configuration (doesn't create bootloader entry)
      (pkgs.writeScriptBin "test-system" ''
        #!/usr/bin/env bash
        # Test system configuration without creating bootloader entry

        ${detectRebuildCmd "test"}
        ${findFlakeDir}

        echo "Testing system configuration from $FLAKE_DIR..."
        cd "$FLAKE_DIR"
        sudo $REBUILD_CMD .#
      '')

      # Build system configuration (doesn't activate)
      (pkgs.writeScriptBin "build-system" ''
        #!/usr/bin/env bash
        # Build system configuration without activating

        ${detectRebuildCmd "build"}
        ${findFlakeDir}

        echo "Building system configuration from $FLAKE_DIR..."
        cd "$FLAKE_DIR"
        sudo $REBUILD_CMD .#
      '')
    ];
  };
}
