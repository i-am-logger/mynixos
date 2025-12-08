{ lib, ... }:

{
  options.graphical = lib.mkOption {
    description = "Graphical environment configuration";
    default = { };
    type = lib.types.submodule {
      options = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Enable graphical environment for this user (auto-enables Hyprland + greetd system services)";
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

        windowManager = lib.mkOption {
          description = "Window manager configuration";
          default = { };
          type = lib.types.submodule {
            options = {
              hyprland = lib.mkOption {
                description = "Hyprland window manager configuration";
                default = { };
                type = lib.types.submodule {
                  options = {
                    enable = lib.mkOption {
                      type = lib.types.bool;
                      default = true;
                      description = "Enable user-specific Hyprland config (opinionated default: enabled when user graphical = true)";
                    };

                    leftHanded = lib.mkOption {
                      type = lib.types.bool;
                      default = false;
                      description = "Left-handed mouse mode (opinionated default: false)";
                    };

                    sensitivity = lib.mkOption {
                      type = lib.types.float;
                      default = 0.0;
                      description = "Mouse sensitivity (opinionated default: 0.0, range: -1.0 to 1.0)";
                    };

                    # NOTE: defaultBrowser and defaultTerminal removed
                    # Browser/terminal now come from environment API:
                    # - my.users.<name>.environment.BROWSER
                    # - my.users.<name>.environment.TERMINAL
                  };
                };
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
}
