{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.my.system;
in
{
  config = mkIf cfg.enable {
    # System utility scripts available to all users
    environment.systemPackages = [
      # Update system flake inputs
      (pkgs.writeScriptBin "update-system" ''
        #!/usr/bin/env bash
        # Update flake inputs for the system configuration
        # Detects the flake location based on common paths
        
        if [ -d "/etc/nixos" ] && [ -f "/etc/nixos/flake.nix" ]; then
          FLAKE_DIR="/etc/nixos"
        elif [ -d "$HOME/.flake" ] && [ -f "$HOME/.flake/flake.nix" ]; then
          FLAKE_DIR="$HOME/.flake"
        else
          echo "Error: Could not find flake.nix in /etc/nixos or ~/.flake"
          exit 1
        fi
        
        echo "Updating flake inputs in $FLAKE_DIR..."
        cd "$FLAKE_DIR"
        nix flake update
      '')

      # Rebuild system configuration
      (pkgs.writeScriptBin "rebuild-system" ''
        #!/usr/bin/env bash
        # Rebuild and switch to new system configuration
        # Detects the flake location and uses appropriate rebuild command
        
        # Determine rebuild command based on platform
        if [[ "$OSTYPE" == "darwin"* ]]; then
          REBUILD_CMD="darwin-rebuild switch --flake"
        else
          REBUILD_CMD="nixos-rebuild switch --flake"
        fi
        
        # Detect flake location
        if [ -d "/etc/nixos" ] && [ -f "/etc/nixos/flake.nix" ]; then
          FLAKE_DIR="/etc/nixos"
        elif [ -d "$HOME/.flake" ] && [ -f "$HOME/.flake/flake.nix" ]; then
          FLAKE_DIR="$HOME/.flake"
        else
          echo "Error: Could not find flake.nix in /etc/nixos or ~/.flake"
          exit 1
        fi
        
        echo "Rebuilding system from $FLAKE_DIR..."
        cd "$FLAKE_DIR"
        sudo $REBUILD_CMD .#
      '')

      # Test system configuration (doesn't create bootloader entry)
      (pkgs.writeScriptBin "test-system" ''
        #!/usr/bin/env bash
        # Test system configuration without creating bootloader entry
        # Useful for testing changes before committing
        
        # Determine rebuild command based on platform
        if [[ "$OSTYPE" == "darwin"* ]]; then
          REBUILD_CMD="darwin-rebuild test --flake"
        else
          REBUILD_CMD="nixos-rebuild test --flake"
        fi
        
        # Detect flake location
        if [ -d "/etc/nixos" ] && [ -f "/etc/nixos/flake.nix" ]; then
          FLAKE_DIR="/etc/nixos"
        elif [ -d "$HOME/.flake" ] && [ -f "$HOME/.flake/flake.nix" ]; then
          FLAKE_DIR="$HOME/.flake"
        else
          echo "Error: Could not find flake.nix in /etc/nixos or ~/.flake"
          exit 1
        fi
        
        echo "Testing system configuration from $FLAKE_DIR..."
        cd "$FLAKE_DIR"
        sudo $REBUILD_CMD .#
      '')

      # Build system configuration (doesn't activate)
      (pkgs.writeScriptBin "build-system" ''
        #!/usr/bin/env bash
        # Build system configuration without activating
        # Useful for checking for build errors
        
        # Determine rebuild command based on platform
        if [[ "$OSTYPE" == "darwin"* ]]; then
          REBUILD_CMD="darwin-rebuild build --flake"
        else
          REBUILD_CMD="nixos-rebuild build --flake"
        fi
        
        # Detect flake location
        if [ -d "/etc/nixos" ] && [ -f "/etc/nixos/flake.nix" ]; then
          FLAKE_DIR="/etc/nixos"
        elif [ -d "$HOME/.flake" ] && [ -f "$HOME/.flake/flake.nix" ]; then
          FLAKE_DIR="$HOME/.flake"
        else
          echo "Error: Could not find flake.nix in /etc/nixos or ~/.flake"
          exit 1
        fi
        
        echo "Building system configuration from $FLAKE_DIR..."
        cd "$FLAKE_DIR"
        sudo $REBUILD_CMD .#
      '')
    ];
  };
}
