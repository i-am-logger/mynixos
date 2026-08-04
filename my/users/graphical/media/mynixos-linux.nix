# mynixos Opinionated Defaults: media/creative apps, Linux.
#
# The half whose packages are Linux-only: krita, gimp and kdenlive do not build
# on aarch64-darwin, mypaint and audacious likewise, and pavucontrol/pamixer and
# the PipeWire CLI are PulseAudio/PipeWire tools with no macOS counterpart --
# CoreAudio is not a drop-in for either.
#
# Imported only by platforms/linux.nix.

{ lib, ... }:

{
  options.my.users = lib.mkOption {
    type = lib.types.attrsOf (lib.types.submodule ({ config, ... }: {
      config = lib.mkIf (config.graphical.media.enable or false) {
        apps = {
          art = {
            drawing.krita.enable = lib.mkDefault (config.graphical.media.krita or true);
            drawing.mypaint.enable = lib.mkDefault (config.graphical.media.mypaint or true);
            editing.gimp.enable = lib.mkDefault (config.graphical.media.gimp or true);
          };
          media = {
            editors.kdenlive.enable = lib.mkDefault (config.graphical.media.kdenlive or false);
            players.audacious.enable = lib.mkDefault (config.graphical.media.audacious or false);
            tools.audioUtils.enable = lib.mkDefault (config.graphical.media.audioUtils or true);
            tools.pipewireTools.enable = lib.mkDefault (config.graphical.media.pipewireTools or true);
          };
        };
      };
    }));
  };
}
