# mynixos Opinionated Defaults: media/creative apps.
#
# `graphical.media.*` is an injector: the bools SET the app options, so
# installation, persistence and unfree handling all run through the app modules
# like every other app.
#
# Linux only, because `graphical.media` is declared only there
# (my/users/graphical/options-linux.nix): krita, gimp and kdenlive do not build
# on aarch64-darwin, mypaint and audacious likewise, and pavucontrol/pamixer and
# the PipeWire CLI are PulseAudio/PipeWire tools with no macOS counterpart. The
# portable apps it also turns on (inkscape, darktable, blender, audacity,
# musikcube) are set directly on a Mac.
#
# Imported only by platforms/linux.nix.

{ lib, ... }:

{
  options.my.users = lib.mkOption {
    type = lib.types.attrsOf (lib.types.submodule ({ config, ... }: {
      config = lib.mkIf config.graphical.media.enable {
        apps = with config.graphical; {
          art = {
            drawing = {
              inkscape.enable = lib.mkDefault media.inkscape;
              krita.enable = lib.mkDefault media.krita;
              mypaint.enable = lib.mkDefault media.mypaint;
            };
            editing = {
              darktable.enable = lib.mkDefault media.darktable;
              gimp.enable = lib.mkDefault media.gimp;
            };
            modeling.blender.enable = lib.mkDefault media.blender;
          };
          media = {
            editors = {
              audacity.enable = lib.mkDefault media.audacity;
              kdenlive.enable = lib.mkDefault media.kdenlive;
            };
            players = {
              audacious.enable = lib.mkDefault media.audacious;
              musikcube.enable = lib.mkDefault media.musikcube;
              vlc.enable = lib.mkDefault media.vlc;
            };
            tools = {
              audioUtils.enable = lib.mkDefault media.audioUtils;
              pipewireTools.enable = lib.mkDefault media.pipewireTools;
            };
          };
        };
      };
    }));
  };
}
