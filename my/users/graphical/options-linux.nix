# Per-user graphical options whose implementations are Linux-only.
#
# `graphical.enable` stays in ./options.nix because it means the same thing
# everywhere -- "this user has a GUI" -- and darwin forces it true. These three
# do not: OBS and the v4l2loopback virtual camera, the browser-webapp .desktop
# generator, and the creative/audio app set are all driven by modules that only
# platforms/linux.nix imports.
#
# Declaring them here means a darwin host that sets one fails with "The option
# `my.users.<n>.graphical.media.enable' does not exist" rather than setting a
# flag nothing on that platform reads.
#
# Loaded by platforms/linux.nix through mkOptionsModule, so this returns
# `{ users = mkOption ...; }`. Type-only at the `graphical` level: ./options.nix
# carries its `default` and `description`, and repeating them here would be a
# duplicate declaration rather than a merge.

{ lib, ... }:

{
  users = lib.mkOption {
    type = lib.types.attrsOf (lib.types.submodule {
      options.graphical = lib.mkOption {
        type = lib.types.submodule {
          options = {
            # The desktop SHELL — bar, notifications, OSD — as a distributed
            # enum, exactly like terminal.multiplexer: this base declaration
            # carries only "none" (no bar, no shell surfaces; locker and
            # launcher stay selectable), and the vogix theming module
            # contributes "vogix" and owns the default. There is deliberately
            # no waybar value and no parallel apps.* switch: the fleet's shell
            # IS the vogix desktop (the omarchy-parity surface set), and two
            # switches for one bar is how options rot.
            shell = lib.mkOption {
              type = lib.types.enum [ "none" ];
              description = "Which desktop shell renders this user's bar and desktop surfaces.";
            };

            # Idle staging, rendered into the shell's idle service (seconds;
            # null disables a stage). Declared here — the person's idle
            # policy, not the theme system's — and wired into
            # programs.vogix.desktop.idle by the vogix theming module.
            idle = {
              screensaver = lib.mkOption {
                type = lib.types.nullOr lib.types.ints.positive;
                default = null;
                description = "Seconds of idle before the screensaver overlay (null = never; the dim stage is the default idle cue).";
              };
              dim = lib.mkOption {
                type = lib.types.nullOr lib.types.ints.positive;
                default = 300;
                description = "Seconds of idle before the screens dim (null = never).";
              };
              lock = lib.mkOption {
                type = lib.types.nullOr lib.types.ints.positive;
                default = 600;
                description = "Seconds of idle before the session locks (null = never).";
              };
              screenOff = lib.mkOption {
                type = lib.types.nullOr lib.types.ints.positive;
                default = 660;
                description = "Seconds of idle before displays power off (null = never).";
              };
              suspend = lib.mkOption {
                type = lib.types.nullOr lib.types.ints.positive;
                default = null;
                description = "Seconds of idle before the machine suspends (null = never).";
              };
            };

            streaming = lib.mkOption {
              description = "Streaming tools configuration";
              default = { };
              type = lib.types.submodule {
                options = {
                  enable = lib.mkOption {
                    type = lib.types.bool;
                    default = false;
                    description = "Enable streaming tools (OBS Studio, requires graphical.enable = true)";
                  };
                };
              };
            };

            webapps = lib.mkOption {
              description = "Browser-based web applications";
              default = { };
              type = lib.types.submodule {
                options = {
                  enable = lib.mkOption {
                    type = lib.types.bool;
                    default = true;
                    description = "Enable webapps (opinionated default: enabled when graphical.enable = true)";
                  };

                  gmail = lib.mkOption { type = lib.types.bool; default = true; description = "Gmail webapp"; };
                  vscode = lib.mkOption { type = lib.types.bool; default = true; description = "VS Code webapp"; };
                  github = lib.mkOption { type = lib.types.bool; default = true; description = "GitHub webapp"; };
                  spotify = lib.mkOption { type = lib.types.bool; default = true; description = "Spotify webapp"; };
                  discord = lib.mkOption { type = lib.types.bool; default = true; description = "Discord webapp"; };
                  whatsapp = lib.mkOption { type = lib.types.bool; default = true; description = "WhatsApp webapp"; };
                  youtube = lib.mkOption { type = lib.types.bool; default = true; description = "YouTube webapp"; };
                  netflix = lib.mkOption { type = lib.types.bool; default = true; description = "Netflix webapp"; };
                  twitch = lib.mkOption { type = lib.types.bool; default = true; description = "Twitch webapp"; };
                  zoom = lib.mkOption { type = lib.types.bool; default = true; description = "Zoom webapp"; };
                  chatgpt = lib.mkOption { type = lib.types.bool; default = true; description = "ChatGPT webapp"; };
                  claude = lib.mkOption { type = lib.types.bool; default = true; description = "Claude webapp"; };
                  grok = lib.mkOption { type = lib.types.bool; default = true; description = "Grok webapp"; };
                  x = lib.mkOption { type = lib.types.bool; default = true; description = "X (Twitter) webapp"; };
                  slack = lib.mkOption { type = lib.types.bool; default = false; description = "Slack (Electron)"; };
                  signal = lib.mkOption { type = lib.types.bool; default = false; description = "Signal (Electron)"; };
                  onePassword = lib.mkOption { type = lib.types.bool; default = false; description = "1Password"; };
                };
              };
            };

            media = lib.mkOption {
              description = "Media and creative applications";
              default = { };
              type = lib.types.submodule {
                options = {
                  enable = lib.mkOption {
                    type = lib.types.bool;
                    default = false;
                    description = "Enable media/creative apps";
                  };

                  mypaint = lib.mkOption { type = lib.types.bool; default = true; description = "MyPaint digital painting"; };
                  krita = lib.mkOption { type = lib.types.bool; default = true; description = "Krita digital painting"; };
                  gimp = lib.mkOption { type = lib.types.bool; default = true; description = "GIMP image editor"; };
                  inkscape = lib.mkOption { type = lib.types.bool; default = true; description = "Inkscape vector graphics"; };
                  blender = lib.mkOption { type = lib.types.bool; default = false; description = "Blender 3D modeling (heavy)"; };
                  darktable = lib.mkOption { type = lib.types.bool; default = false; description = "Darktable RAW editing (heavy)"; };
                  audacity = lib.mkOption { type = lib.types.bool; default = false; description = "Audacity audio editor"; };
                  kdenlive = lib.mkOption { type = lib.types.bool; default = false; description = "Kdenlive video editor"; };
                  musikcube = lib.mkOption { type = lib.types.bool; default = false; description = "Musikcube music player"; };
                  audacious = lib.mkOption { type = lib.types.bool; default = false; description = "Audacious music player"; };
                  pipewireTools = lib.mkOption { type = lib.types.bool; default = true; description = "PipeWire CLI tools"; };
                  audioUtils = lib.mkOption { type = lib.types.bool; default = true; description = "Audio utilities (pavucontrol, pamixer)"; };
                };
              };
            };
          };
        };
      };
    });
  };
}
