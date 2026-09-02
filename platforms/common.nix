# mynixos composition layer: modules valid on EVERY platform.
#
# This file, together with ./linux.nix and ./darwin.nix, is the single source of
# truth for what a mynixos system is made of. Platform reach is expressed by
# WHICH FILE imports a module, not by a `pkgs.stdenv.hostPlatform.isX` test and
# not by a list maintained in a downstream flake.
#
# The practical consequence: a file imported only by ./darwin.nix cannot run on
# Linux, so it needs no platform guard at all. Prefer moving the platform-specific
# part of a module into a sibling file over scattering `mkIf isLinux` through a
# shared one.
#
# FILE NAMING. Roles are carried by the filename, and platform variants keep the
# role in the name:
#   options.nix          option declarations
#   default.nix          implementation
#   mynixos.nix          opinionated-defaults injector
#   <role>-<platform>    a platform-specific variant of that role, e.g.
#                        mynixos-darwin.nix is an INJECTOR that only darwin loads,
#                        while my/users/users/darwin.nix sits beside default.nix and
#                        is therefore an IMPLEMENTATION. Do not name an injector
#                        plain <platform>.nix -- it reads as an implementation.
#
# A module belongs here when it both EVALUATES and is MEANINGFUL on Linux and
# darwin. Modules that are structurally portable (they emit only
# `home-manager.users.*`) but whose packages are Wayland/X11-only live in
# ./linux.nix -- putting them here would buy nothing and risk evaluation.

{ lib, ... }:

let
  # Import an options module. Args are passed through directly.
  #
  # Do NOT capture `pkgs` from the module function args here: that triggers
  # `_module.args.pkgs` evaluation, which depends on config.nixpkgs, causing
  # infinite recursion when hardware modules set nixpkgs.hostPlatform.
  mkOptionsModule = path: args: _: { options.my = import path args; };
in
{
  config = {
    # Helpers available to all modules.
    #
    # NOTE: mkApp is intentionally NOT delivered here. It is imported directly by
    # each app module (lib/mk-app.nix). Routing it through _module.args caused
    # infinite recursion: an app module's return value *is* `mkApp args {...}`, so
    # mkApp is forced at module-structure time, and resolving _module.args.mkApp
    # requires the full config -- config -> imports -> config. activeUsers is safe
    # because it is only forced lazily inside config bodies.
    _module.args.activeUsers = import ../lib/active-users.nix lib;
  };

  imports =
    # ---------------------------------------------------------------------
    # Option declarations (loaded first). Pure lib, no `pkgs`.
    # ---------------------------------------------------------------------
    [
      # Per-app option declarations that live beside their implementation but
      # are not mkApp modules (so they cannot carry the option in their spec).
      ../my/users/apps/security/1password/options.nix
      ../my/users/apps/ai/claude-code/options.nix
      ../my/users/apps/git/options.nix
      ../my/users/apps/ssh/options.nix
      ../my/users/apps/communication/discord/options.nix

      # Each multiplexer contributes its own name to the terminal.multiplexer
      # enum (lib.types.enum merges across declarations), so importing one here
      # is what makes it selectable. herdr's also carries the enum's default.
      ../my/users/apps/multiplexers/tmux/options.nix
      ../my/users/apps/multiplexers/zellij/options.nix
      ../my/users/apps/multiplexers/herdr/options.nix

      (mkOptionsModule ../my/fonts/options.nix { inherit lib; })

      # Top-level options
      (mkOptionsModule ../my/system/options.nix { inherit lib; })
      (mkOptionsModule ../my/dev/development/options.nix { inherit lib; })

      # Network options

      # Category-level options
      (mkOptionsModule ../my/hardware/options.nix { inherit lib; })

      # Cross-cutting options

      # Users options
      (mkOptionsModule ../my/users/users/options.nix { inherit lib; })

      # Secrets (special - uses different pattern)
      (import ../my/secrets/options.nix)
    ]

    # ---------------------------------------------------------------------
    # Users opinionated defaults (mynixos.nix files)
    # ---------------------------------------------------------------------
    ++ [
      ../my/users/terminal/mynixos.nix
      ../my/users/graphical/mynixos.nix
      ../my/users/dev/mynixos.nix
      ../my/users/ai/mynixos.nix
      ../my/users/environment/mynixos.nix
    ]

    # ---------------------------------------------------------------------
    # Implementations: system-level, portable
    # ---------------------------------------------------------------------
    ++ [
      ../my/secrets
      ../my/system/nixpkgs-fixes
      ../my/system/scripts
      ../my/system/unfree
    ]

    # ---------------------------------------------------------------------
    # Implementations: per-user. These emit only `home-manager.users.<name>.*`,
    # an attribute path nix-darwin provides too, so they port unchanged.
    # ---------------------------------------------------------------------
    ++ [
      ../my/users/defaults
      ../my/users/environment-defaults
      ../my/users/terminal

      # AI
      ../my/users/apps/ai/claude-code
      ../my/users/apps/ai/babysitter

      # Art

      # Browsers
      ../my/users/apps/browsers/brave
      ../my/users/apps/browsers/chromium
      ../my/users/apps/browsers/firefox

      # Communication
      ../my/users/apps/communication/element
      ../my/users/apps/communication/signal
      ../my/users/apps/communication/slack

      # Development
      ../my/users/apps/dev/devenv
      ../my/users/apps/dev/direnv
      ../my/users/apps/dev/github-desktop
      ../my/users/apps/dev/jq
      ../my/users/apps/dev/kdiff3
      ../my/users/apps/dev/radicle

      # Editors
      ../my/users/apps/editors/helix
      ../my/users/apps/editors/marktext

      # File managers / utils
      ../my/users/apps/file-managers/mc
      ../my/users/apps/file-managers/yazi
      ../my/users/apps/file-utils/lsd

      # Finance / fun
      ../my/users/apps/finance/cointop
      ../my/users/apps/fun/pipes

      # Git / VCS
      ../my/users/apps/git
      ../my/users/apps/jujutsu

      # Media
      ../my/users/apps/media/musikcube
      ../my/users/apps/art/inkscape
      ../my/users/apps/art/blender
      ../my/users/apps/art/darktable
      ../my/users/apps/media/audacity

      # Multiplexers
      ../my/users/apps/multiplexers/tmux
      ../my/users/apps/multiplexers/zellij
      ../my/users/apps/multiplexers/herdr

      # Network
      ../my/users/apps/network/rustdesk
      ../my/users/apps/network/termscp

      # Prompts
      ../my/users/apps/prompts/starship

      # Shells. zsh is the default login shell on both platforms.
      ../my/users/apps/shells/bash
      ../my/users/apps/shells/fish
      ../my/users/apps/shells/zsh

      # SSH
      ../my/users/apps/ssh

      # Sync
      ../my/users/apps/sync/rclone

      # System info
      ../my/users/apps/system-info/btop
      ../my/users/apps/system-info/fastfetch
      ../my/users/apps/system-info/neofetch

      # Terminals
      ../my/users/apps/terminals/alacritty
      ../my/users/apps/terminals/ghostty
      ../my/users/apps/terminals/kitty
      ../my/users/apps/terminals/warp
      ../my/users/apps/terminals/wezterm

      # Utilities
      ../my/users/apps/utils/calculator
      ../my/users/apps/utils/imagemagick

      # Viewers
      ../my/users/apps/viewers/bat

      # Visualizers
      ../my/users/apps/visualizers/cava

      # XDG
      ../my/users/apps/xdg
      ../my/fonts
      ../my/system/base-packages
      ../my/users/graphical/media/mynixos.nix
      ../my/users/webapps/mynixos.nix
      ../my/users/apps/tools/fd
      ../my/users/apps/tools/ripgrep
      ../my/users/apps/tools/zoxide
      ../my/users/apps/tools/fzf
    ];
}
