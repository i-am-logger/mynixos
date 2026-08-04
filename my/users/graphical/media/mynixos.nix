# mynixos Opinionated Defaults: media/creative apps.
#
# `graphical.media.*` used to install packages directly, alongside ~5 mkApp
# modules for the same programs that sat permanently at enable = false. Two
# mechanisms, one concept, and only one of them was read.
#
# It is now an injector: the bools SET the app options, so installation,
# persistence and unfree handling all run through the app modules like every
# other app. The portable half is here; krita, gimp, kdenlive, mypaint,
# audacious and the PulseAudio tools are in ./mynixos-linux.nix because their
# packages do not build on darwin.

{ lib, ... }:

{
  options.my.users = lib.mkOption {
    type = lib.types.attrsOf (lib.types.submodule ({ config, ... }: {
      config = lib.mkIf (config.graphical.media.enable or false) {
        apps = {
          art = {
            drawing.inkscape.enable = lib.mkDefault (config.graphical.media.inkscape or true);
            editing.darktable.enable = lib.mkDefault (config.graphical.media.darktable or false);
            modeling.blender.enable = lib.mkDefault (config.graphical.media.blender or false);
          };
          media = {
            editors.audacity.enable = lib.mkDefault (config.graphical.media.audacity or false);
            players.musikcube.enable = lib.mkDefault (config.graphical.media.musikcube or false);
          };
        };
      };
    }));
  };
}
