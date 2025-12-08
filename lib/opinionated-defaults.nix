# mynixos Opinionated Defaults
# 
# This file defines which apps are enabled by default in mynixos.
# Users can override any of these in their user config with:
#   apps.<category>.<app>.enable = false;
#
# These defaults apply when the corresponding feature is enabled:
# - terminal.enable = true (default) → terminal apps below
# - graphical.enable = true → graphical apps below
# - dev.enable = true → dev apps below

{ lib }:

{
  # Terminal apps (enabled when terminal.enable = true, which defaults to true)
  terminal = {
    shells.bash.enable = lib.mkDefault true;
    prompts.starship.enable = lib.mkDefault true;
    viewers.bat.enable = lib.mkDefault true;
    # Add more opinionated terminal defaults here
  };

  # Graphical apps (enabled when graphical.enable = true)
  graphical = {
    terminals.wezterm.enable = lib.mkDefault true;
    browsers.brave.enable = lib.mkDefault true;
    # Add more opinionated graphical defaults here
  };

  # Dev apps (enabled when dev.enable = true)
  dev = {
    # Dev apps are controlled by dev.enable feature flag
    # Individual apps default to enabled when dev.enable = true
  };
}
