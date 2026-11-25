# my.hardware.display: the domain's own checks. Rendering belongs to the
# compositor module (my/graphical/hyprland); what is wrong with a declaration is
# wrong whichever compositor reads it, so it is asserted here.
{ config, lib, ... }:

{
  config.assertions = (import ./resolve.nix { inherit lib; } config.my.hardware.display).assertions;
}
