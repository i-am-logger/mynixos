# Pointer preferences on macOS.
#
# Both keys are user-scoped in the plist but written through
# `system.defaults.NSGlobalDomain`, which nix-darwin applies to
# `system.primaryUser`. macOS therefore gets ONE user's preference where Linux
# gets each user's own; where the values differ, the primary user wins. That is a
# platform limitation, recorded here rather than modelled into the option.
#
# Imported only by platforms/darwin.nix, so no isDarwin guard is needed.
{ activeUsers, config, lib, ... }:

let
  users = activeUsers config.my.users;
  primary = config.system.primaryUser or null;
  cfg =
    if primary != null && users ? ${primary}
    then users.${primary}.input
    else null;
in
{
  config = lib.mkIf (cfg != null) {
    # Content follows finger direction. The single macOS switch covers mouse and
    # trackpad alike. nix-darwin types this one.
    system.defaults.NSGlobalDomain."com.apple.swipescrolldirection" = cfg.naturalScroll;

    # Primary button on the right. macOS applies this to the mouse only; the
    # trackpad has no handedness setting.
    #
    # nix-darwin has no typed option for this key, so it goes through the
    # freeform CustomUserPreferences escape hatch. It lands in the same
    # NSGlobalDomain plist as the line above; the split is nix-darwin's coverage,
    # not two different places.
    system.defaults.CustomUserPreferences.NSGlobalDomain."com.apple.mouse.swapLeftRightButton" =
      cfg.leftHanded;
  };
}
