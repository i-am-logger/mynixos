{ lib, ... }:

let
  appLib = import ../../../lib/app-options.nix { inherit lib; };
  inherit (appLib) floatBetween;
in
{
  options = {
    apps = lib.mkOption {
      type = lib.types.submodule {
        options = {
          # ========================================
          # TERMINAL APPS (apps.terminal.*)
          # ========================================
          terminal = lib.mkOption {
            type = lib.types.submodule {
              options = {
                # Shells
                shells = lib.mkOption {
                  type = lib.types.submodule {
                    options = {
                      bash = appLib.mkAppOption {
                        name = "Bash";
                        default = false;
                        description = "Bash shell";
                        persistedFiles = [ ".bash_history" ];
                        extraOptions = {
                          historySize = lib.mkOption {
                            type = lib.types.int;
                            default = 10000;
                            description = "Number of commands to keep in history";
                          };
                          historyFileSize = lib.mkOption {
                            type = lib.types.int;
                            default = 10000;
                            description = "Number of lines to keep in history file";
                          };
                          historyControl = lib.mkOption {
                            type = lib.types.listOf lib.types.str;
                            default = [
                              "ignoredups"
                              "ignorespace"
                            ];
                            description = "History control options";
                          };
                          shellOptions = lib.mkOption {
                            type = lib.types.listOf lib.types.str;
                            default = [
                              "histappend"
                              "checkwinsize"
                              "extglob"
                              "globstar"
                              "checkjobs"
                            ];
                            description = "Shell options (shopt)";
                          };
                        };
                      };

                      fish = appLib.mkAppOption {
                        name = "fish";
                        default = false;
                        description = "Fish shell";
                        persistedDirectories = [ ];
                      };
                    };
                  };
                  default = { };
                  description = "Shell applications";
                };

                # Prompts
                prompts = lib.mkOption {
                  type = lib.types.submodule {
                    options = {
                      starship = appLib.mkAppOption {
                        name = "Starship";
                        default = false;
                        description = "Starship prompt";
                        persistedDirectories = [ ".config/starship" ];
                      };
                    };
                  };
                  default = { };
                  description = "Shell prompts";
                };

                # File utilities
                fileUtils = lib.mkOption {
                  type = lib.types.submodule {
                    options = {
                      lsd = appLib.mkAppOption {
                        name = "lsd";
                        default = false;
                        description = "LSDeluxe file lister";
                        persistedDirectories = [ ];
                      };
                    };
                  };
                  default = { };
                  description = "File utilities";
                };

                # File managers
                fileManagers = lib.mkOption {
                  type = lib.types.submodule {
                    options = {
                      yazi = appLib.mkAppOption {
                        name = "yazi";
                        default = false;
                        description = "Yazi terminal file manager";
                        persistedDirectories = [ ".config/yazi" ];
                      };
                      mc = appLib.mkAppOption {
                        name = "mc";
                        default = false;
                        description = "Midnight Commander";
                        persistedDirectories = [ ];
                      };
                    };
                  };
                  default = { };
                  description = "File managers";
                };

                # Multiplexers
                multiplexers = lib.mkOption {
                  type = lib.types.submodule {
                    options = {
                      zellij = appLib.mkAppOption {
                        name = "zellij";
                        default = false;
                        description = "Zellij terminal multiplexer";
                        persistedDirectories = [ ".config/zellij" ];
                      };
                      tmux = appLib.mkAppOption {
                        name = "tmux";
                        default = false;
                        description = "tmux multiplexer";
                        persistedDirectories = [ ];
                      };
                    };
                  };
                  default = { };
                  description = "Terminal multiplexers";
                };

                # System info
                sysinfo = lib.mkOption {
                  type = lib.types.submodule {
                    options = {
                      fastfetch = appLib.mkAppOption {
                        name = "fastfetch";
                        default = false;
                        description = "Fastfetch system info";
                        persistedDirectories = [ ];
                      };
                      btop = appLib.mkAppOption {
                        name = "btop";
                        default = false;
                        description = "btop system monitor";
                        persistedDirectories = [ ];
                      };
                      neofetch = appLib.mkAppOption {
                        name = "neofetch";
                        default = false;
                        description = "neofetch system info";
                        persistedDirectories = [ ];
                      };
                    };
                  };
                  default = { };
                  description = "System information tools";
                };

                # Viewers
                viewers = lib.mkOption {
                  type = lib.types.submodule {
                    options = {
                      bat = appLib.mkAppOption {
                        name = "bat";
                        default = false;
                        description = "Bat file viewer";
                        persistedDirectories = [ ];
                      };
                      feh = appLib.mkAppOption {
                        name = "feh";
                        default = false;
                        description = "feh image viewer";
                        persistedDirectories = [ ];
                      };
                    };
                  };
                  default = { };
                  description = "File viewers";
                };

                # Visualizers
                visualizers = lib.mkOption {
                  type = lib.types.submodule {
                    options = {
                      cava = appLib.mkAppOption {
                        name = "cava";
                        default = false;
                        description = "cava audio visualizer";
                        persistedDirectories = [
                          ".config/cava/shaders"
                          ".config/cava/themes"
                        ];
                        extraOptions = {
                          gradientMode = lib.mkOption {
                            type = lib.types.enum [
                              "rainbow"
                              "vumeter"
                              "custom"
                            ];
                            default = "vumeter";
                            description = ''
                              Gradient color mode for cava visualization (styled by Stylix):
                              - rainbow: Full spectrum (magenta → blue → cyan → green → yellow → orange → red)
                              - vumeter: VU meter/dB scale (cyan → green → yellow → orange → red)
                                Represents audio amplitude: quiet → normal → loud → clipping
                              - custom: Disable automatic gradient (manual configuration)
                            '';
                          };
                        };
                      };
                      bespec = appLib.mkAppOption {
                        name = "bespec";
                        default = true;
                        description = "BeSpec real-time audio spectrum visualizer with peak hold";
                        persistedDirectories = [
                          ".config/BeSpec"
                        ];
                      };
                    };
                  };
                  default = { };
                  description = "Audio/visual visualizers";
                };

                # Network
                network = lib.mkOption {
                  type = lib.types.submodule {
                    options = {
                      termscp = appLib.mkAppOption {
                        name = "termscp";
                        default = false;
                        description = "termscp TUI file transfer";
                        persistedDirectories = [ ];
                      };
                    };
                  };
                  default = { };
                  description = "Network tools";
                };

                # Fun
                fun = lib.mkOption {
                  type = lib.types.submodule {
                    options = {
                      pipes = appLib.mkAppOption {
                        name = "pipes";
                        default = false;
                        description = "Terminal eye candy (pipes, neo, asciiquarium)";
                        persistedDirectories = [ ];
                      };
                    };
                  };
                  default = { };
                  description = "Fun terminal programs";
                };
              };
            };
            default = { };
            description = "Terminal-based applications";
          };

          # ========================================
          # GRAPHICAL APPS (apps.graphical.*)
          # ========================================
          graphical = lib.mkOption {
            type = lib.types.submodule {
              options = {
                # Window managers
                windowManagers = lib.mkOption {
                  type = lib.types.submodule {
                    options = {
                      hyprland = appLib.mkAppOption {
                        name = "Hyprland";
                        default = false;
                        description = "Hyprland window manager";
                        persistedDirectories = [ ".config/hypr" ];
                        extraOptions = {
                          leftHanded = lib.mkOption {
                            type = lib.types.bool;
                            default = false;
                            description = "Left-handed mouse mode";
                          };
                          sensitivity = lib.mkOption {
                            type = floatBetween (-1.0) 1.0;
                            default = 0.0;
                            description = "Mouse sensitivity (range: -1.0 to 1.0)";
                          };

                          # General settings
                          gaps_in = lib.mkOption {
                            type = lib.types.ints.unsigned;
                            default = 10;
                            description = "Inner gaps between windows (pixels)";
                          };
                          gaps_out = lib.mkOption {
                            type = lib.types.ints.unsigned;
                            default = 10;
                            description = "Outer gaps between windows and screen edge (pixels)";
                          };
                          border_size = lib.mkOption {
                            type = lib.types.ints.unsigned;
                            default = 3;
                            description = "Window border size (pixels)";
                          };
                          layout = lib.mkOption {
                            type = lib.types.enum [ "dwindle" "master" ];
                            default = "dwindle";
                            description = "Default tiling layout";
                          };

                          # Decoration settings
                          rounding = lib.mkOption {
                            type = lib.types.ints.unsigned;
                            default = 8;
                            description = "Corner rounding radius (pixels)";
                          };
                          active_opacity = lib.mkOption {
                            type = floatBetween 0.0 1.0;
                            default = 1.0;
                            description = "Opacity of focused windows (range: 0.0 to 1.0)";
                          };
                          inactive_opacity = lib.mkOption {
                            type = floatBetween 0.0 1.0;
                            default = 1.0;
                            description = "Opacity of unfocused windows (range: 0.0 to 1.0)";
                          };
                          dim_inactive = lib.mkOption {
                            type = lib.types.bool;
                            default = true;
                            description = "Dim inactive windows";
                          };
                          dim_strength = lib.mkOption {
                            type = floatBetween 0.0 1.0;
                            default = 0.3;
                            description = "Dim strength for inactive windows (range: 0.0 to 1.0)";
                          };

                          # Animation settings
                          animations_enabled = lib.mkOption {
                            type = lib.types.bool;
                            default = true;
                            description = "Enable window animations";
                          };

                          # Blur settings
                          blur_enabled = lib.mkOption {
                            type = lib.types.bool;
                            default = true;
                            description = "Enable background blur";
                          };
                          blur_size = lib.mkOption {
                            type = lib.types.ints.unsigned;
                            default = 3;
                            description = "Blur size (intensity)";
                          };

                          # Escape hatch for advanced config
                          extraSettings = lib.mkOption {
                            type = lib.types.attrsOf lib.types.anything;
                            default = { };
                            description = "Additional Hyprland settings (passthrough to wayland.windowManager.hyprland.settings)";
                          };
                        };
                      };
                    };
                  };
                  default = { };
                  description = "Window managers";
                };

                # Browsers
                browsers = lib.mkOption {
                  type = lib.types.submodule {
                    options = {
                      brave = appLib.mkAppOption {
                        name = "brave";
                        default = false;
                        description = "Brave browser";
                        persistedDirectories = [ ".config/BraveSoftware" ];
                      };
                      firefox = appLib.mkAppOption {
                        name = "firefox";
                        default = false;
                        description = "Firefox browser";
                        persistedDirectories = [ ];
                      };
                      chromium = appLib.mkAppOption {
                        name = "chromium";
                        default = false;
                        description = "Chromium browser";
                        persistedDirectories = [ ];
                      };
                    };
                  };
                  default = { };
                  description = "Web browsers";
                };

                # Terminals
                terminals = lib.mkOption {
                  type = lib.types.submodule {
                    options = {
                      wezterm = appLib.mkAppOption {
                        name = "wezterm";
                        default = false;
                        description = "WezTerm terminal";
                        persistedDirectories = [ ".config/wezterm" ];
                      };
                      kitty = appLib.mkAppOption {
                        name = "kitty";
                        default = false;
                        description = "Kitty terminal";
                        persistedDirectories = [ ];
                      };
                      ghostty = appLib.mkAppOption {
                        name = "ghostty";
                        default = false;
                        description = "Ghostty terminal";
                        persistedDirectories = [ ];
                      };
                      alacritty = appLib.mkAppOption {
                        name = "alacritty";
                        default = false;
                        description = "Alacritty terminal";
                        persistedDirectories = [ ];
                      };
                      warp = appLib.mkAppOption {
                        name = "warp";
                        default = false;
                        description = "Warp terminal";
                        persistedDirectories = [ ];
                      };
                    };
                  };
                  default = { };
                  description = "Terminal emulators";
                };

                # Editors
                editors = lib.mkOption {
                  type = lib.types.submodule {
                    options = {
                      helix = appLib.mkAppOption {
                        name = "helix";
                        default = false;
                        description = "Helix editor";
                        persistedDirectories = [ ".config/helix" ];
                      };
                      marktext = appLib.mkAppOption {
                        name = "marktext";
                        default = false;
                        description = "MarkText markdown editor";
                        persistedDirectories = [ ];
                      };
                    };
                  };
                  default = { };
                  description = "Text editors";
                };

                # Launchers
                launchers = lib.mkOption {
                  type = lib.types.submodule {
                    options = {
                      walker = appLib.mkAppOption {
                        name = "Walker";
                        default = false;
                        description = "Walker application launcher";
                        persistedDirectories = [ ".config/walker" ];
                      };
                    };
                  };
                  default = { };
                  description = "Application launchers";
                };

                # Status bars
                statusbars = lib.mkOption {
                  type = lib.types.submodule {
                    options = {
                      waybar = appLib.mkAppOption {
                        name = "waybar";
                        default = false;
                        description = "Waybar status bar";
                        persistedDirectories = [ ];
                      };
                    };
                  };
                  default = { };
                  description = "Status bars";
                };

                # Viewers
                viewers = lib.mkOption {
                  type = lib.types.submodule {
                    options = {
                      feh = appLib.mkAppOption {
                        name = "feh";
                        default = false;
                        description = "feh image viewer";
                        persistedDirectories = [ ];
                      };
                    };
                  };
                  default = { };
                  description = "Image/file viewers";
                };

                # Utilities
                utils = lib.mkOption {
                  type = lib.types.submodule {
                    options = {
                      calculator = appLib.mkAppOption {
                        name = "calculator";
                        default = false;
                        description = "Calculator (qalculate)";
                        persistedDirectories = [ ];
                      };
                      imagemagick = appLib.mkAppOption {
                        name = "ImageMagick";
                        default = false;
                        description = "ImageMagick image manipulation";
                        persistedDirectories = [ ];
                      };
                    };
                  };
                  default = { };
                  description = "Utilities";
                };

                # Sync
                sync = lib.mkOption {
                  type = lib.types.submodule {
                    options = {
                      rclone = appLib.mkAppOption {
                        name = "rclone";
                        default = false;
                        description = "rclone cloud sync";
                        persistedDirectories = [ ".config/rclone" ];
                      };
                    };
                  };
                  default = { };
                  description = "Sync tools";
                };
              };
            };
            default = { };
            description = "Graphical applications";
          };

          # ========================================
          # DEV APPS (apps.dev.*)
          # ========================================
          dev = lib.mkOption {
            type = lib.types.submodule {
              options = {
                tools = lib.mkOption {
                  type = lib.types.submodule {
                    options = {
                      direnv = appLib.mkAppOption {
                        name = "direnv";
                        default = false;
                        description = "direnv environment manager";
                        persistedDirectories = [
                          ".direnv"
                          ".local/share/direnv"
                        ];
                      };
                      devenv = appLib.mkAppOption {
                        name = "devenv";
                        default = false;
                        description = "devenv development environment manager";
                        persistedDirectories = [ ];
                      };
                      vscode = appLib.mkAppOption {
                        name = "VSCode";
                        default = false;
                        description = "Visual Studio Code editor";
                        persistedDirectories = [
                          ".vscode"
                          ".claude"
                        ];
                      };
                      jq = appLib.mkAppOption {
                        name = "jq";
                        default = false;
                        description = "jq JSON processor";
                        persistedDirectories = [ ];
                      };
                      kdiff3 = appLib.mkAppOption {
                        name = "kdiff3";
                        default = false;
                        description = "KDiff3 diff tool";
                        persistedDirectories = [ ];
                      };
                      githubDesktop = appLib.mkAppOption {
                        name = "githubDesktop";
                        default = false;
                        description = "GitHub Desktop";
                        persistedDirectories = [ ];
                      };
                    };
                  };
                  default = { };
                  description = "Development tools";
                };
              };
            };
            default = { };
            description = "Development applications";
          };

          # ========================================
          # MEDIA APPS (apps.media.*)
          # ========================================
          media = lib.mkOption {
            type = lib.types.submodule {
              options = {
                players = lib.mkOption {
                  type = lib.types.submodule {
                    options = {
                      musikcube = appLib.mkAppOption {
                        name = "musikcube";
                        default = false;
                        description = "musikcube music player";
                        persistedDirectories = [ ];
                      };
                      audacious = appLib.mkAppOption {
                        name = "audacious";
                        default = false;
                        description = "Audacious music player";
                        persistedDirectories = [ ];
                      };
                    };
                  };
                  default = { };
                  description = "Media players";
                };

                tools = lib.mkOption {
                  type = lib.types.submodule {
                    options = {
                      pipewireTools = appLib.mkAppOption {
                        name = "PipeWire Tools";
                        default = false;
                        description = "PipeWire CLI tools";
                        persistedDirectories = [ ];
                      };
                      audioUtils = appLib.mkAppOption {
                        name = "Audio Utilities";
                        default = false;
                        description = "Audio utilities (pavucontrol, pamixer)";
                        persistedDirectories = [ ];
                      };
                    };
                  };
                  default = { };
                  description = "Media tools";
                };
              };
            };
            default = { };
            description = "Media applications";
          };

          # ========================================
          # ART APPS (apps.art.*)
          # ========================================
          art = lib.mkOption {
            type = lib.types.submodule {
              options = {
                drawing = lib.mkOption {
                  type = lib.types.submodule {
                    options = {
                      mypaint = appLib.mkAppOption {
                        name = "mypaint";
                        default = false;
                        description = "MyPaint drawing application";
                        persistedDirectories = [ ];
                      };
                    };
                  };
                  default = { };
                  description = "Drawing applications";
                };
              };
            };
            default = { };
            description = "Art and creative applications";
          };

          # ========================================
          # COMMUNICATION APPS (apps.communication.*)
          # ========================================
          communication = lib.mkOption {
            type = lib.types.submodule {
              options = {
                messaging = lib.mkOption {
                  type = lib.types.submodule {
                    options = {
                      element = appLib.mkAppOption {
                        name = "element";
                        default = false;
                        description = "Element Matrix client";
                        persistedDirectories = [ ];
                      };
                      signal = appLib.mkAppOption {
                        name = "signal";
                        default = false;
                        description = "Signal Desktop messenger";
                        persistedDirectories = [ ];
                      };
                      slack = appLib.mkAppOption {
                        name = "slack";
                        default = false;
                        description = "Slack communication tool";
                        persistedDirectories = [ ];
                      };
                    };
                  };
                  default = { };
                  description = "Messaging applications";
                };
              };
            };
            default = { };
            description = "Communication applications";
          };

          # ========================================
          # SECURITY APPS (apps.security.*)
          # ========================================
          security = lib.mkOption {
            type = lib.types.submodule {
              options = {
                passwords = lib.mkOption {
                  type = lib.types.submodule {
                    options = {
                      onePassword = appLib.mkAppOption {
                        name = "1Password";
                        default = false;
                        description = "1Password password manager";
                        persistedDirectories = [ ".config/1Password" ];
                      };
                    };
                  };
                  default = { };
                  description = "Password managers";
                };
              };
            };
            default = { };
            description = "Security applications";
          };

          # ========================================
          # AI APPS (apps.ai.*)
          # ========================================
          ai = lib.mkOption {
            type = lib.types.submodule {
              options = {
                tools = lib.mkOption {
                  type = lib.types.submodule {
                    options = {
                      opencode = appLib.mkAppOption {
                        name = "OpenCode";
                        default = false;
                        description = "OpenCode AI coding assistant";
                        persistedDirectories = [
                          ".claude"
                          ".config/opencode"
                        ];
                      };
                      claude-code = appLib.mkAppOption {
                        name = "Claude Code";
                        default = false;
                        description = "Claude Code AI coding assistant";
                        persistedDirectories = [ ".claude" ];
                        persistedFiles = [ ".claude.json" ];
                        extraOptions = {
                          cloneConfigRepo = lib.mkOption {
                            type = lib.types.nullOr lib.types.nonEmptyStr;
                            default = null;
                            description = "Git URL to clone into ~/.claude on first boot (syncs settings, memory, todos across machines)";
                          };
                        };
                      };
                    };
                  };
                  default = { };
                  description = "AI tools";
                };
              };
            };
            default = { };
            description = "AI applications";
          };

          # ========================================
          # FINANCE APPS (apps.finance.*)
          # ========================================
          finance = lib.mkOption {
            type = lib.types.submodule {
              options = {
                tracking = lib.mkOption {
                  type = lib.types.submodule {
                    options = {
                      cointop = appLib.mkAppOption {
                        name = "cointop";
                        default = false;
                        description = "Cointop cryptocurrency tracker";
                        persistedDirectories = [ ];
                      };
                    };
                  };
                  default = { };
                  description = "Financial tracking";
                };
              };
            };
            default = { };
            description = "Finance applications";
          };
        };
      };
      default = { };
      description = "Per-user application configurations (categorized by feature and type)";
    };
  };
}
