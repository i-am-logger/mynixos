{ config, lib, pkgs, ... }:

with lib;

let
  # Check if ANY user has graphical.media enabled
  anyUserMedia = any (u: u.graphical.media.enable or false) (attrValues config.my.users);
in
{
  config = mkIf anyUserMedia {
    # Per-user home-manager packages
    home-manager.users = mapAttrs
      (name: userCfg:
        let
          mediaCfg = userCfg.graphical.media or { };
        in
        mkIf (mediaCfg.enable or false) {
          home.packages = with pkgs;
            # Painting/Drawing
            (optional (mediaCfg.mypaint or true) mypaint) ++
            (optional (mediaCfg.krita or true) krita) ++

            # Image Editing
            (optional (mediaCfg.gimp or true) gimp) ++
            (optional (mediaCfg.inkscape or true) inkscape) ++

            # Heavy Apps (disabled by default)
            (optional (mediaCfg.blender or false) blender) ++
            (optional (mediaCfg.darktable or false) darktable) ++

            # Audio Editing
            (optional (mediaCfg.audacity or false) audacity) ++

            # Video Editing
            (optional (mediaCfg.kdenlive or false) kdenlive) ++

            # Music Players
            (optional (mediaCfg.musikcube or false) musikcube) ++
            (optional (mediaCfg.audacious or false) audacious) ++

            # Audio Tools
            (optional (mediaCfg.pipewireTools or true) pipewire) ++
            (optionals (mediaCfg.audioUtils or true) [
              pavucontrol  # PulseAudio/PipeWire volume control GUI
              pamixer      # PulseAudio/PipeWire CLI mixer
            ]);
        })
      config.my.users;
  };
}
