args:

(import ../../../../../lib/mk-app.nix).mkApp args {
  path = "terminal.visualizers.cava";
  option = {
    name = "cava";
    default = false;
    description = "cava audio visualizer";
    persistedDirectories = [
      ".config/cava/shaders"
      ".config/cava/themes"
    ];
    extraOptions = { };
  };
  home = { lib, pkgs, ... }:
    let
      inherit (pkgs.stdenv.hostPlatform) isDarwin;
    in
    lib.mkMerge [
      {
        # cava-peaks: cava driven in raw mode with peak-hold caps, rendered here
        # so the caps decay on their own timeline. Aliased `cvp` by the shells.
        home.packages = [ (pkgs.callPackage ../../../../../packages/cava-peaks { }) ];

        programs.cava = {
          enable = true;

          # Everything here is mkDefault so a host can retune without mkForce.
          settings = {
            general = {
              framerate = lib.mkDefault 60;
              autosens = lib.mkDefault 1;
              sensitivity = lib.mkDefault 100;
              bars = lib.mkDefault 0; # Auto-calculate based on terminal width
              bar_width = lib.mkDefault 2;
              bar_spacing = lib.mkDefault 1; # Spacing between bars
              higher_cutoff_freq = lib.mkDefault 22000; # Full frequency range
            };

            # macOS: cava 1.0.0's native Core Audio backend can tap system
            # output DIRECTLY on macOS 14.2+, with no loopback device -- so no
            # Background Music, which is unpackageable anyway (HAL plugin in
            # /Library, a _BGMXPCHelper service account, a coreaudiod restart).
            # See overlays/cava.nix for the version bump and the patch that
            # makes the tap actually compile.
            #
            # ONE-TIME MANUAL STEP: macOS gates taps behind TCC. The first run
            # prints "AudioTap permissions missing! requesting..." -- grant the
            # TERMINAL app (not cava) "System Audio Recording Only" in System
            # Settings > Privacy & Security. cava inherits the terminal's grant.
            #
            # Fallback if you would rather not grant it, or on macOS < 14.2:
            #   method = "portaudio"; source = "Background Music";
            # which needs Background Music installed by hand.
            #
            # There is no pipewire backend on darwin, and cava's auto-selected
            # default is fifo, so the method is always named explicitly.
            input =
              if isDarwin then {
                method = lib.mkDefault "coreaudio";
                source = lib.mkDefault "tap";
              } else {
                method = lib.mkDefault "pipewire";
                source = lib.mkDefault "auto";
              };

            output = {
              # noncurses supports the shader pipeline on Linux; the darwin
              # build is terminal-only, so ncurses there.
              method = lib.mkDefault (if isDarwin then "ncurses" else "noncurses");
              channels = lib.mkDefault "mono";
              mono_option = lib.mkDefault "average"; # average L+R; or 'left'/'right'
            };

            smoothing = {
              # Monstercat spreads each bar's energy into its neighbours, giving
              # the rounded, blobby look. Off: the bars stay crisp.
              monstercat = lib.mkDefault 0;
              waves = lib.mkDefault 0; # Disable waves mode
              gravity = lib.mkDefault 100; # Higher = slower fall = smoother
              ignore = lib.mkDefault 0; # Sensitivity cutoff
              # Primary knob (0-100). 0 = fast and twitchy, 100 = slow and
              # syrupy; drives both the integral and gravity filters internally.
              noise_reduction = lib.mkDefault 45;
            };
          };
        };
      }

      # Linux leaves the colours alone: with no `color` section cava uses the
      # terminal's own palette. On a host running vogix that palette is themed;
      # on one that is not it is whatever the terminal is set to. Either way it is
      # the host's choice, and a fixed gradient here would override both.
      #
      # macOS gets an explicit gradient because mynixos has no darwin theming
      # system, so there is no palette to defer to.
      #
      # Every value is mkDefault, so a host can retune without mkForce.
      (lib.mkIf isDarwin {
        programs.cava.settings.color = {
          gradient = lib.mkDefault 1;
          gradient_count = lib.mkDefault 6;
          gradient_color_1 = lib.mkDefault "'#2e9ef4'";
          gradient_color_2 = lib.mkDefault "'#22b3c8'";
          gradient_color_3 = lib.mkDefault "'#1cc7a0'";
          gradient_color_4 = lib.mkDefault "'#63d13c'";
          gradient_color_5 = lib.mkDefault "'#d9c62b'";
          gradient_color_6 = lib.mkDefault "'#f45d5d'";
        };
      })
    ];
}
