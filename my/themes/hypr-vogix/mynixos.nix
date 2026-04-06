# Hypr-vogix opinionated defaults
# Auto-enables hypr-vogix when theming is active
{ lib, ... }:

{
  config = {
    my.themes.hypr-vogix.enable = lib.mkDefault false; # TODO: move into vogix
  };
}
