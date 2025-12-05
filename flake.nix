{
  description = "mynixos - A typed functional DSL for NixOS configuration";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    # Partition management
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Tmpfs persistence
    impermanence = {
      url = "github:nix-community/impermanence";
    };

    # User configuration and dotfiles
    home-manager = {
      url = "github:i-am-logger/home-manager?ref=feature/webapps-module";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Themes and styling
    stylix = {
      url = "github:danth/stylix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Secure boot
    lanzaboote = {
      url = "github:nix-community/lanzaboote";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Hardware configurations
    nixos-hardware = {
      url = "github:i-am-logger/nixos-hardware";
    };

    # Secrets management
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, disko, impermanence, home-manager, stylix, lanzaboote, nixos-hardware, sops-nix, ... }@inputs:
    let
      lib = nixpkgs.lib;

      # Passkey type constructors (exported at flake level for use in configs)
      yubikey = { serialNumber, gpgKeyId ? null, ... }: {
        type = "yubikey";
        inherit serialNumber gpgKeyId;
      };

      solokey = { serialNumber, ... }: {
        type = "solokey";
        inherit serialNumber;
      };

      nitrokey = { serialNumber, ... }: {
        type = "nitrokey";
        inherit serialNumber;
      };

    in
    {
      # Export type constructors for use in system configs
      inherit yubikey solokey nitrokey;

      # Export hardware profiles (generic, anyone with this hardware can use)
      hardware = {
        motherboards = {
          gigabyte = {
            x870e-aorus-elite-wifi7 = ./modules/hardware/motherboards/gigabyte/x870e-aorus-elite-wifi7;
          };
        };
        laptops = {
          lenovo = {
            legion-16irx8h = ./modules/hardware/laptops/lenovo/legion-16irx8h;
          };
        };
        cooling = {
          nzxt = {
            kraken-elite-rgb = {
              elite-240-rgb = ./modules/hardware/cooling/nzxt/kraken-elite-rgb/elite-240-rgb.nix;
            };
          };
        };
      };

      # Main NixOS module providing the `my.*` namespace
      nixosModules.default = { config, lib, pkgs, ... }:
        let
          cfg = config.my;
        in
        {
          imports = [
            # Import external modules
            impermanence.nixosModules.impermanence
            lanzaboote.nixosModules.lanzaboote

            # mynixos modules
            # Features
            ./modules/features/users.nix
            ./modules/features/security.nix
            ./modules/features/graphical.nix
            ./modules/features/hyprland.nix
            ./modules/features/themes.nix
            ./modules/features/github-runner.nix
            ./modules/features/ai.nix
            ./modules/features/webapps.nix
            ./modules/features/streaming.nix
            ./modules/features/development.nix
            ./modules/features/system.nix
            ./modules/features/audio.nix
            ./modules/features/performance.nix
            ./modules/features/impermanence.nix
            ./modules/features/motd.nix

            # Presets
            ./modules/presets/workstation.nix

            # Apps
            ./modules/apps/browsers/brave.nix
            ./modules/apps/browsers/firefox.nix
            ./modules/apps/terminals/wezterm.nix
            ./modules/apps/terminals/kitty.nix
            ./modules/apps/terminals/ghostty.nix
            ./modules/apps/terminals/alacritty.nix
            ./modules/apps/editors/helix.nix
            ./modules/apps/editors/marktext.nix
            ./modules/apps/shells/bash.nix
            ./modules/apps/shells/fish.nix
            ./modules/apps/prompts/starship.nix
            ./modules/apps/fileManagers/mc.nix
            ./modules/apps/fileManagers/yazi.nix
            ./modules/apps/multiplexers/zellij.nix
            ./modules/apps/multiplexers/tmux.nix
            ./modules/apps/viewers/bat.nix
            ./modules/apps/viewers/feh.nix
            ./modules/apps/fileUtils/lsd.nix
            ./modules/apps/sysinfo/btop.nix
            ./modules/apps/sysinfo/neofetch.nix
            ./modules/apps/sysinfo/fastfetch.nix
            ./modules/apps/visualizers/cava.nix
            ./modules/apps/launchers/walker.nix
            ./modules/apps/sync/rclone.nix
            ./modules/apps/utils/calculator.nix
            ./modules/apps/utils/imagemagick.nix
            ./modules/apps/dev/direnv.nix
            ./modules/apps/dev/devenv.nix
            ./modules/apps/dev/github-desktop.nix
            ./modules/apps/dev/kdiff3.nix
            ./modules/apps/dev/jq.nix
            ./modules/apps/media/pipewire-tools.nix
            ./modules/apps/media/musikcube.nix
            ./modules/apps/media/audacious.nix
            ./modules/apps/media/audio-utils.nix
            ./modules/apps/communication/element.nix
            ./modules/apps/communication/signal.nix
            ./modules/apps/communication/slack.nix
            ./modules/apps/terminals/warp.nix
            ./modules/apps/finance/cointop.nix
            ./modules/apps/art/mypaint.nix
            ./modules/apps/network/termscp.nix
            ./modules/apps/fun/pipes.nix
            ./modules/apps/git.nix
            ./modules/apps/jujutsu.nix
            ./modules/apps/ssh.nix
            ./modules/apps/xdg.nix

            # Security
            ./modules/security/yubikey.nix

            # Hardware
            ./modules/hardware/cpu/amd.nix
            ./modules/hardware/cpu/intel.nix
            ./modules/hardware/gpu/amd.nix
            ./modules/hardware/gpu/nvidia.nix
            ./modules/hardware/bluetooth/realtek.nix
            ./modules/hardware/cooling/nzxt/kraken-elite-rgb/elite-240-rgb.nix
            ./modules/hardware/boot/uefi.nix
            ./modules/hardware/boot/dual-boot.nix
            # Motherboard/laptop configs are in /etc/nixos/Hardware/ and imported via mkSystem's hardware parameter

            # System
            # (filesystem configuration is handled directly in mkSystem based on my.system.filesystem)

            # Infrastructure
            ./modules/infra/services/k3s.nix
          ];

          options.my = {
            # Features namespace
            features = lib.mkOption {
              type = lib.types.submodule {
                options = {
                  # Security stack
                  security = lib.mkOption {
                    description = "Security stack configuration";
                    default = { };
                    type = lib.types.submodule {
                      options = {
                        enable = lib.mkEnableOption "security stack";

                        secureBoot = {
                          enable = lib.mkEnableOption "secure boot with lanzaboote";
                        };

                        yubikey = {
                          enable = lib.mkEnableOption "yubikey support";
                        };

                        auditRules = {
                          enable = lib.mkEnableOption "audit rules";
                        };
                      };
                    };
                  };

                  # Graphical environment feature
                  graphical = lib.mkOption {
                    description = "Graphical environment with opinionated defaults";
                    default = { };
                    type = lib.types.submodule {
                      options = {
                        enable = lib.mkEnableOption "graphical environment (Hyprland + greetd)";

                        browser = {
                          enable = lib.mkOption {
                            type = lib.types.bool;
                            default = true;
                            description = "Browser (brave) - opinionated default: enabled";
                          };
                        };

                        # Window managers
                        windowManagers = {
                          hyprland = lib.mkOption {
                            type = lib.types.bool;
                            default = true;
                            description = "Hyprland wayland compositor (opinionated default: enabled)";
                          };
                        };

                        # Hyprland configuration
                        hyprland = {
                          input = {
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
                          };
                          defaultBrowser = lib.mkOption {
                            type = lib.types.str;
                            default = "brave";
                            description = "Default browser for Super+E keybind (opinionated default: brave)";
                          };
                          defaultTerminal = lib.mkOption {
                            type = lib.types.str;
                            default = "wezterm";
                            description = "Default terminal for Super+T keybind (opinionated default: wezterm)";
                          };
                        };

                        # Webapps (browser-based and Electron applications)
                        webapps = lib.mkOption {
                          description = "Browser-based and Electron applications";
                          default = { };
                          type = lib.types.submodule {
                            options = {
                              enable = lib.mkOption {
                                type = lib.types.bool;
                                default = true;
                                description = "Webapps stack - opinionated default: enabled";
                              };

                              # Individual webapps - all enabled by default when webapps.enable = true
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

                              # Electron apps
                              slack = lib.mkOption { type = lib.types.bool; default = false; description = "Slack (Electron)"; };
                              signal = lib.mkOption { type = lib.types.bool; default = false; description = "Signal (Electron)"; };

                              # Password managers
                              onePassword = lib.mkOption { type = lib.types.bool; default = false; description = "1Password"; };
                            };
                          };
                        };
                      };
                    };
                  };

                  # GitHub Runner stack
                  github-runner = lib.mkOption {
                    description = "GitHub Actions Runner Controller stack";
                    default = { };
                    type = lib.types.submodule {
                      options = {
                        enable = lib.mkEnableOption "GitHub Actions runners with k3s and ARC";

                        enableGpu = lib.mkOption {
                          type = lib.types.bool;
                          default = false;
                          description = "Enable GPU passthrough to runners (vendor auto-detected from hardware)";
                        };

                        useCustomImage = lib.mkOption {
                          type = lib.types.bool;
                          default = true;
                          description = "Use custom GitHub runner image from GHCR";
                        };

                        repositories = lib.mkOption {
                          type = lib.types.listOf lib.types.str;
                          default = [ ];
                          description = "List of repository names to create runner sets for";
                        };
                      };
                    };
                  };

                  # Performance tuning
                  performance = lib.mkOption {
                    description = "Performance optimizations (kernel tunables, zram, vmtouch)";
                    default = { };
                    type = lib.types.submodule {
                      options = {
                        enable = lib.mkEnableOption "performance optimizations";

                        zramPercent = lib.mkOption {
                          type = lib.types.int;
                          default = 15;
                          description = "Percentage of RAM to use for zram compressed swap";
                        };

                        vmtouchCache = lib.mkOption {
                          type = lib.types.bool;
                          default = false;
                          description = "Enable vmtouch RAM caching for system closure";
                        };
                      };
                    };
                  };

                  # AI stack
                  ai = lib.mkOption {
                    description = "AI infrastructure (Ollama + MCP servers)";
                    default = { };
                    type = lib.types.submodule {
                      options = {
                        enable = lib.mkEnableOption "AI infrastructure with Ollama and ROCm support";

                        rocmGfxVersion = lib.mkOption {
                          type = lib.types.str;
                          default = "11.0.2";
                          description = "ROCm GFX version override for AMD GPU compatibility (opinionated default: 11.0.2 for RDNA3)";
                        };

                        mcpServers = {
                          enable = lib.mkEnableOption "Model Context Protocol servers";
                        };
                      };
                    };
                  };

                  # Streaming feature
                  streaming = lib.mkOption {
                    description = "Content creation and streaming tools";
                    default = { };
                    type = lib.types.submodule {
                      options = {
                        enable = lib.mkEnableOption "streaming stack with v4l2loopback";

                        obs = {
                          enable = lib.mkOption {
                            type = lib.types.bool;
                            default = true;
                            description = "OBS Studio with plugins (opinionated default: enabled)";
                          };
                        };

                        streamdeck = {
                          enable = lib.mkEnableOption "StreamDeck support";
                        };
                      };
                    };
                  };

                  # Development feature
                  development = lib.mkOption {
                    description = "Development tools and environment";
                    default = { };
                    type = lib.types.submodule {
                      options = {
                        enable = lib.mkEnableOption "development stack";

                        docker = {
                          enable = lib.mkOption {
                            type = lib.types.bool;
                            default = true;
                            description = "Docker with rootless support (opinionated default: enabled)";
                          };
                        };

                        direnv = {
                          enable = lib.mkOption {
                            type = lib.types.bool;
                            default = true;
                            description = "direnv environment manager (opinionated default: enabled)";
                          };
                        };

                        binfmt = {
                          enable = lib.mkOption {
                            type = lib.types.bool;
                            default = true;
                            description = "binfmt emulation for aarch64-linux (opinionated default: enabled)";
                          };

                          appimage = lib.mkOption {
                            type = lib.types.bool;
                            default = true;
                            description = "AppImage support via binfmt (opinionated default: enabled)";
                          };
                        };

                        vscode = {
                          enable = lib.mkEnableOption "Visual Studio Code (requires graphical.enable = true)";
                        };

                        k3s = lib.mkOption {
                          description = "k3s Kubernetes cluster for local development";
                          default = { };
                          type = lib.types.submodule {
                            options = {
                              enable = lib.mkOption {
                                type = lib.types.bool;
                                default = true;
                                description = "k3s Kubernetes cluster (opinionated default: enabled)";
                              };

                              role = lib.mkOption {
                                type = lib.types.enum [ "server" "agent" ];
                                default = "server";
                                description = "k3s role - server or agent";
                              };

                              disableTraefik = lib.mkOption {
                                type = lib.types.bool;
                                default = true;
                                description = "Disable built-in Traefik ingress controller";
                              };

                              apiPort = lib.mkOption {
                                type = lib.types.port;
                                default = 6443;
                                description = "k3s API server port";
                              };

                              kubeconfigReadable = lib.mkOption {
                                type = lib.types.bool;
                                default = true;
                                description = "Make kubeconfig readable by non-root users";
                              };
                            };
                          };
                        };
                      };
                    };
                  };

                  # System feature
                  system = lib.mkOption {
                    description = "Core system utilities and configuration";
                    default = { };
                    type = lib.types.submodule {
                      options = {
                        enable = lib.mkEnableOption "system utilities (console, nix, environment)";

                        xdg = {
                          enable = lib.mkEnableOption "XDG portal support for Wayland";
                        };
                      };
                    };
                  };

                };
              };
              default = { };
              description = "Functional features configuration";
            };

            # Hardware namespace
            hardware = lib.mkOption {
              type = lib.types.submodule {
                options = {
                  cpu = lib.mkOption {
                    type = lib.types.nullOr (lib.types.enum [ "amd" "intel" ]);
                    default = null;
                    description = "CPU vendor";
                  };

                  gpu = lib.mkOption {
                    type = lib.types.nullOr (lib.types.enum [ "amd" "nvidia" "intel" ]);
                    default = null;
                    description = "GPU vendor";
                  };

                  bluetooth = {
                    enable = lib.mkOption {
                      type = lib.types.bool;
                      default = true;
                      description = "Enable bluetooth";
                    };
                  };

                  audio = {
                    enable = lib.mkOption {
                      type = lib.types.bool;
                      default = true;
                      description = "Enable audio";
                    };
                  };
                };
              };
              default = { };
              description = "Hardware configuration";
            };

            # Presets namespace
            presets = lib.mkOption {
              type = lib.types.submodule {
                options = {
                  workstation = {
                    enable = lib.mkEnableOption "workstation preset with opinionated app defaults";
                  };
                };
              };
              default = { };
              description = "Preset configurations";
            };

            # Users namespace (moved from features)
            users = lib.mkOption {
              description = "User configurations";
              default = { };
              type = lib.types.attrsOf (lib.types.submodule ({ name, ... }: {
                options = {
                  name = lib.mkOption {
                    type = lib.types.str;
                    default = name;
                    description = "Username";
                  };

                  fullName = lib.mkOption {
                    type = lib.types.nullOr lib.types.str;
                    default = null;
                    description = "Full name for git, etc (required if user is fully managed by mynixos)";
                  };

                  description = lib.mkOption {
                    type = lib.types.nullOr lib.types.str;
                    default = null;
                    description = "User account description (displayed in login manager)";
                  };

                  email = lib.mkOption {
                    type = lib.types.nullOr lib.types.str;
                    default = null;
                    description = "Email for git, etc (required for git configuration)";
                  };

                  githubUsername = lib.mkOption {
                    type = lib.types.nullOr lib.types.str;
                    default = null;
                    description = "GitHub username (for github-runner, etc)";
                  };

                  packages = lib.mkOption {
                    type = lib.types.listOf lib.types.package;
                    default = [ ];
                    description = "User-specific packages";
                  };

                  shell = lib.mkOption {
                    type = lib.types.nullOr lib.types.str;
                    default = null;
                    description = "Default shell (fish, bash, zsh)";
                  };

                  hashedPassword = lib.mkOption {
                    type = lib.types.nullOr lib.types.str;
                    default = null;
                    description = "Hashed password for user account (if null, user must set password manually)";
                  };

                  editor = lib.mkOption {
                    type = lib.types.nullOr lib.types.str;
                    default = null;
                    description = "Default editor (helix, vim, neovim)";
                  };

                  avatar = lib.mkOption {
                    type = lib.types.nullOr lib.types.path;
                    default = null;
                    description = "Path to user avatar/icon image (PNG recommended, will be set up for AccountsService)";
                  };

                  yubikeys = lib.mkOption {
                    type = lib.types.listOf (lib.types.submodule {
                      options = {
                        serial = lib.mkOption {
                          type = lib.types.str;
                          description = "YubiKey serial number";
                        };

                        keyId = lib.mkOption {
                          type = lib.types.str;
                          description = "GPG key ID (short form)";
                        };

                        fingerprint = lib.mkOption {
                          type = lib.types.str;
                          description = "Full GPG key fingerprint";
                        };

                        sshKeygrip = lib.mkOption {
                          type = lib.types.str;
                          description = "SSH authentication key keygrip";
                        };

                        publicKeyPath = lib.mkOption {
                          type = lib.types.path;
                          description = "Path to GPG public key file (.asc)";
                        };
                      };
                    });
                    default = [ ];
                    description = "YubiKey configurations for this user";
                  };

                  mounts = lib.mkOption {
                    type = lib.types.listOf (lib.types.submodule {
                      options = {
                        mountPoint = lib.mkOption {
                          type = lib.types.str;
                          description = "Mount point path (relative to user home or absolute)";
                        };

                        device = lib.mkOption {
                          type = lib.types.str;
                          description = "Device path or UUID (will be prefixed with /dev/disk/by-uuid/ if not a full path)";
                        };

                        fsType = lib.mkOption {
                          type = lib.types.str;
                          default = "ext4";
                          description = "Filesystem type";
                        };

                        options = lib.mkOption {
                          type = lib.types.listOf lib.types.str;
                          default = [ "defaults" ];
                          description = "Mount options";
                        };

                        noCheck = lib.mkOption {
                          type = lib.types.bool;
                          default = false;
                          description = "Skip filesystem check";
                        };
                      };
                    });
                    default = [ ];
                    description = "User-specific filesystem mounts";
                  };
                };
              }));
            };

            # Apps namespace
            apps = lib.mkOption {
              type = lib.types.submodule {
                options = {
                  browsers = {
                    brave = lib.mkOption {
                      type = lib.types.bool;
                      default = true;
                      description = "Brave browser (opinionated default: enabled)";
                    };
                    firefox = lib.mkEnableOption "Firefox browser";
                  };

                  terminals = {
                    wezterm = lib.mkOption {
                      type = lib.types.bool;
                      default = true;
                      description = "WezTerm terminal (opinionated default: enabled)";
                    };
                    kitty = lib.mkEnableOption "Kitty";
                    ghostty = lib.mkEnableOption "Ghostty";
                    alacritty = lib.mkEnableOption "Alacritty terminal";
                    warp = lib.mkEnableOption "Warp terminal";
                  };

                  editors = {
                    helix = lib.mkOption {
                      type = lib.types.bool;
                      default = true;
                      description = "Helix editor (opinionated default: enabled)";
                    };
                    neovim = lib.mkEnableOption "Neovim";
                    marktext = lib.mkEnableOption "MarkText markdown editor";
                  };

                  shells = {
                    bash = lib.mkOption {
                      type = lib.types.bool;
                      default = true;
                      description = "Bash shell (default shell)";
                    };
                    fish = lib.mkEnableOption "Fish shell";
                  };

                  prompts = {
                    starship = lib.mkOption {
                      type = lib.types.bool;
                      default = true;
                      description = "Starship prompt (opinionated default: enabled)";
                    };
                  };

                  fileManagers = {
                    mc = lib.mkEnableOption "Midnight Commander";
                    yazi = lib.mkOption {
                      type = lib.types.bool;
                      default = true;
                      description = "Yazi TUI file manager (opinionated default: enabled)";
                    };
                  };

                  multiplexers = {
                    zellij = lib.mkOption {
                      type = lib.types.bool;
                      default = true;
                      description = "Zellij multiplexer (opinionated default: enabled)";
                    };
                    tmux = lib.mkEnableOption "tmux multiplexer";
                  };

                  viewers = {
                    bat = lib.mkOption {
                      type = lib.types.bool;
                      default = true;
                      description = "bat syntax highlighter (opinionated default: enabled)";
                    };
                    feh = lib.mkOption {
                      type = lib.types.bool;
                      default = true;
                      description = "feh image viewer (opinionated default: enabled)";
                    };
                  };

                  fileUtils = {
                    lsd = lib.mkOption {
                      type = lib.types.bool;
                      default = true;
                      description = "lsd directory lister (opinionated default: enabled)";
                    };
                  };

                  sysinfo = {
                    btop = lib.mkEnableOption "btop system monitor";
                    neofetch = lib.mkEnableOption "neofetch system info";
                    fastfetch = lib.mkOption {
                      type = lib.types.bool;
                      default = true;
                      description = "fastfetch system info (opinionated default: enabled)";
                    };
                  };

                  launchers = {
                    walker = lib.mkOption {
                      type = lib.types.bool;
                      default = true;
                      description = "Walker application launcher (opinionated default: enabled)";
                    };
                  };

                  sync = {
                    rclone = lib.mkOption {
                      type = lib.types.bool;
                      default = true;
                      description = "rclone cloud sync (opinionated default: enabled)";
                    };
                  };

                  utils = {
                    calculator = lib.mkEnableOption "Calculator (qalculate)";
                    imagemagick = lib.mkOption {
                      type = lib.types.bool;
                      default = true;
                      description = "ImageMagick image manipulation (opinionated default: enabled)";
                    };
                  };

                  visualizers = {
                    cava = lib.mkEnableOption "cava audio visualizer";
                  };

                  dev = {
                    direnv = lib.mkOption {
                      type = lib.types.bool;
                      default = true;
                      description = "direnv environment manager (opinionated default: enabled)";
                    };
                    devenv = lib.mkEnableOption "devenv development environment manager";
                    githubDesktop = lib.mkEnableOption "GitHub Desktop";
                    kdiff3 = lib.mkEnableOption "KDiff3 diff tool";
                    jq = lib.mkOption {
                      type = lib.types.bool;
                      default = true;
                      description = "jq JSON processor (opinionated default: enabled)";
                    };
                  };

                  media = {
                    pipewireTools = lib.mkOption {
                      type = lib.types.bool;
                      default = true;
                      description = "PipeWire CLI tools (opinionated default: enabled)";
                    };
                    musikcube = lib.mkEnableOption "musikcube music player";
                    audacious = lib.mkEnableOption "Audacious music player";
                    audioUtils = lib.mkOption {
                      type = lib.types.bool;
                      default = true;
                      description = "Audio utilities (pavucontrol, pamixer) (opinionated default: enabled)";
                    };
                  };

                  art = {
                    mypaint = lib.mkEnableOption "MyPaint drawing application";
                  };

                  network = {
                    termscp = lib.mkEnableOption "termscp TUI file transfer";
                  };

                  fun = {
                    pipes = lib.mkEnableOption "Terminal eye candy (pipes, neo, asciiquarium)";
                  };

                  finance = {
                    cointop = lib.mkEnableOption "Cointop cryptocurrency tracker";
                  };

                  communication = {
                    element = lib.mkEnableOption "Element Matrix client";
                    signal = lib.mkEnableOption "Signal Desktop messenger";
                    slack = lib.mkEnableOption "Slack communication tool";
                  };

                  # New apps
                  git = lib.mkOption {
                    type = lib.types.bool;
                    default = true;
                    description = "Git with opinionated config (opinionated default: enabled)";
                  };
                  jujutsu = lib.mkEnableOption "Jujutsu version control";
                  ssh = lib.mkOption {
                    type = lib.types.bool;
                    default = true;
                    description = "SSH with YubiKey optimizations (opinionated default: enabled)";
                  };
                  browserWebapps = lib.mkEnableOption "Browser-based web applications (Gmail, Spotify, Discord, etc.)";
                  xdg = lib.mkOption {
                    type = lib.types.bool;
                    default = true;
                    description = "XDG directories configuration (opinionated default: enabled)";
                  };
                };
              };
              default = { };
              description = "Application configurations";
            };

            # Infrastructure namespace
            infra = lib.mkOption {
              type = lib.types.submodule {
                options = {
                  services = {
                    k3s = lib.mkOption {
                      description = "k3s Kubernetes cluster configuration";
                      default = { };
                      type = lib.types.submodule {
                        options = {
                          enable = lib.mkEnableOption "k3s Kubernetes cluster";

                          role = lib.mkOption {
                            type = lib.types.enum [ "server" "agent" ];
                            default = "server";
                            description = "k3s role - server or agent";
                          };

                          disableTraefik = lib.mkOption {
                            type = lib.types.bool;
                            default = true;
                            description = "Disable built-in Traefik ingress controller";
                          };

                          apiPort = lib.mkOption {
                            type = lib.types.port;
                            default = 6443;
                            description = "k3s API server port";
                          };

                          kubeconfigReadable = lib.mkOption {
                            type = lib.types.bool;
                            default = true;
                            description = "Make kubeconfig readable by non-root users";
                          };
                        };
                      };
                    };
                  };
                };
              };
              default = { };
              description = "Infrastructure services and applications";
            };

            # Storage namespace
            storage = lib.mkOption {
              description = "Storage and filesystem configuration (disko + impermanence)";
              default = { };
              type = lib.types.submodule {
                options = {
                  # Impermanence configuration
                  impermanence = lib.mkOption {
                    description = "Tmpfs root with persistent storage";
                    default = { };
                    type = lib.types.submodule {
                      options = {
                        enable = lib.mkEnableOption "impermanence with opinionated defaults";

                        persistPath = lib.mkOption {
                          type = lib.types.str;
                          default = "/persist";
                          description = "Path to persistent storage directory";
                        };

                        useDedicatedPartition = lib.mkOption {
                          type = lib.types.bool;
                          default = true;
                          description = "Use dedicated partition for persistent storage (vs tmpfiles)";
                        };

                        persistUserData = lib.mkOption {
                          type = lib.types.bool;
                          default = true;
                          description = "Persist user data directories (Media, Code)";
                        };

                        cloneFlakeRepo = lib.mkOption {
                          type = lib.types.nullOr lib.types.str;
                          default = null;
                          description = "Git URL to clone into /etc/nixos on first boot";
                        };

                        symlinkFlakeToHome = lib.mkOption {
                          type = lib.types.nullOr lib.types.str;
                          default = null;
                          description = "Username to create ~/.flake symlink for";
                        };

                        extraSystemDirectories = lib.mkOption {
                          type = lib.types.listOf lib.types.str;
                          default = [ ];
                          description = "Additional system directories to persist";
                        };

                        extraUserDirectories = lib.mkOption {
                          type = lib.types.listOf lib.types.str;
                          default = [ ];
                          description = "Additional user directories to persist (applied to all users)";
                        };

                        extraUserFiles = lib.mkOption {
                          type = lib.types.listOf lib.types.str;
                          default = [ ];
                          description = "Additional user files to persist (applied to all users)";
                        };
                      };
                    };
                  };

                  # TODO: Add disko configuration options here in the future
                  # disko = lib.mkOption { ... };
                };
              };
            };

            # Boot namespace
            boot = {
              # UEFI boot support
              uefi = lib.mkOption {
                type = lib.types.bool;
                default = true;
                description = "Enable UEFI boot";
              };

              # Secure boot with Lanzaboote
              secure = lib.mkEnableOption "Secure Boot with Lanzaboote";

              # Dual-boot support
              dualBoot = {
                enable = lib.mkEnableOption "dual-boot support (Windows/Linux)";
              };
            };

            # Filesystem namespace
            filesystem = {
              type = lib.mkOption {
                type = lib.types.nullOr (lib.types.enum [ "disko" "nixos" ]);
                default = null;
                description = "Filesystem configuration type (disko for declarative partitioning, nixos for standard NixOS)";
              };

              config = lib.mkOption {
                type = lib.types.nullOr lib.types.path;
                default = null;
                description = "Path to filesystem configuration file (disko.nix or filesystem.nix)";
              };
            };

            # Themes namespace
            themes = lib.mkOption {
              description = "Theming configuration (Stylix-based)";
              default = { };
              type = lib.types.submodule {
                options = {
                  type = lib.mkOption {
                    type = lib.types.nullOr (lib.types.enum [ "stylix" ]);
                    default = null;
                    description = "Theme system type (currently only stylix is supported)";
                  };

                  config = lib.mkOption {
                    type = lib.types.nullOr lib.types.path;
                    default = null;
                    description = "Path to theme configuration file (e.g., stylix.nix)";
                  };

                  enable = lib.mkEnableOption "theming system";

                  polarity = lib.mkOption {
                    type = lib.types.enum [ "light" "dark" ];
                    default = "dark";
                    description = "Color scheme polarity";
                  };

                  wallpaper = lib.mkOption {
                    type = lib.types.nullOr lib.types.path;
                    default = null;
                    description = "Path to wallpaper image";
                  };

                  colorScheme = lib.mkOption {
                    type = lib.types.nullOr lib.types.path;
                    default = null;
                    description = "Path to base16 YAML color scheme";
                  };

                  opacity = lib.mkOption {
                    type = lib.types.submodule {
                      options = {
                        applications = lib.mkOption {
                          type = lib.types.float;
                          default = 0.95;
                          description = "Opacity for applications (0.0-1.0)";
                        };
                        desktop = lib.mkOption {
                          type = lib.types.float;
                          default = 0.95;
                          description = "Opacity for desktop (0.0-1.0)";
                        };
                        popups = lib.mkOption {
                          type = lib.types.float;
                          default = 0.95;
                          description = "Opacity for popups (0.0-1.0)";
                        };
                        terminal = lib.mkOption {
                          type = lib.types.float;
                          default = 0.95;
                          description = "Opacity for terminal (0.0-1.0)";
                        };
                      };
                    };
                    default = { };
                    description = "Opacity settings for different UI elements";
                  };

                  fonts = lib.mkOption {
                    type = lib.types.submodule {
                      options = {
                        sizes = lib.mkOption {
                          type = lib.types.submodule {
                            options = {
                              applications = lib.mkOption {
                                type = lib.types.int;
                                default = 28;
                                description = "Font size for applications";
                              };
                              desktop = lib.mkOption {
                                type = lib.types.int;
                                default = 32;
                                description = "Font size for desktop";
                              };
                              popups = lib.mkOption {
                                type = lib.types.int;
                                default = 28;
                                description = "Font size for popups";
                              };
                              terminal = lib.mkOption {
                                type = lib.types.int;
                                default = 32;
                                description = "Font size for terminal";
                              };
                            };
                          };
                          default = { };
                          description = "Font sizes for different UI elements";
                        };

                        serif = lib.mkOption {
                          type = lib.types.submodule {
                            options = {
                              name = lib.mkOption {
                                type = lib.types.str;
                                default = "Noto Nerd Font";
                                description = "Serif font name";
                              };
                              package = lib.mkOption {
                                type = lib.types.package;
                                default = pkgs.nerd-fonts.noto;
                                description = "Serif font package";
                              };
                            };
                          };
                          default = { };
                          description = "Serif font configuration";
                        };

                        sansSerif = lib.mkOption {
                          type = lib.types.submodule {
                            options = {
                              name = lib.mkOption {
                                type = lib.types.str;
                                default = "FiraCode Nerd Font";
                                description = "Sans-serif font name";
                              };
                              package = lib.mkOption {
                                type = lib.types.package;
                                default = pkgs.nerd-fonts.fira-code;
                                description = "Sans-serif font package";
                              };
                            };
                          };
                          default = { };
                          description = "Sans-serif font configuration";
                        };

                        monospace = lib.mkOption {
                          type = lib.types.submodule {
                            options = {
                              name = lib.mkOption {
                                type = lib.types.str;
                                default = "FiraCode Nerd Font";
                                description = "Monospace font name";
                              };
                              package = lib.mkOption {
                                type = lib.types.package;
                                default = pkgs.nerd-fonts.fira-code;
                                description = "Monospace font package";
                              };
                            };
                          };
                          default = { };
                          description = "Monospace font configuration";
                        };

                        emoji = lib.mkOption {
                          type = lib.types.submodule {
                            options = {
                              name = lib.mkOption {
                                type = lib.types.str;
                                default = "Noto Color Emoji";
                                description = "Emoji font name";
                              };
                              package = lib.mkOption {
                                type = lib.types.package;
                                default = pkgs.noto-fonts-color-emoji;
                                description = "Emoji font package";
                              };
                            };
                          };
                          default = { };
                          description = "Emoji font configuration";
                        };
                      };
                    };
                    default = { };
                    description = "Font configuration";
                  };

                  cursor = lib.mkOption {
                    type = lib.types.submodule {
                      options = {
                        name = lib.mkOption {
                          type = lib.types.str;
                          default = "Bibata-Modern-Amber";
                          description = "Cursor theme name";
                        };
                        package = lib.mkOption {
                          type = lib.types.package;
                          default = pkgs.bibata-cursors;
                          description = "Cursor theme package";
                        };
                        size = lib.mkOption {
                          type = lib.types.int;
                          default = 24;
                          description = "Cursor size";
                        };
                      };
                    };
                    default = { };
                    description = "Cursor theme configuration";
                  };
                };
              };
            };
          };

          config = {
            # Placeholder - actual implementations will be in separate module files
            # that import based on my.* options
          };
        };

      # Export library functions
      lib = {
        inherit yubikey solokey nitrokey;

        # System builder - the core mynixos API
        mkSystem = (import ./lib/mkSystem.nix { inherit inputs lib nixpkgs; self = self; }).mkSystem;

        # Installer ISO builder
        mkInstallerISO = (import ./lib/mkInstallerISO.nix { inherit inputs lib nixpkgs; }).mkInstallerISO;
      };

      # Formatter for nix code
      formatter.x86_64-linux = nixpkgs.legacyPackages.x86_64-linux.nixpkgs-fmt;
    };
}
