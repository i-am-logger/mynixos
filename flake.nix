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
            x870e-aorus-elite-wifi7 = ./my/hardware/motherboards/gigabyte/x870e-aorus-elite-wifi7;
          };
        };
        laptops = {
          lenovo = {
            legion-16irx8h = ./my/hardware/laptops/lenovo/legion-16irx8h;
          };
        };
        cooling = {
          nzxt = {
            kraken-elite-rgb = {
              elite-240-rgb = ./my/hardware/cooling/nzxt/kraken-elite-rgb/elite-240-rgb.nix;
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
            # Users
            ./my/users/users.nix
            ./my/users/defaults
            ./my/users/webapps/webapps.nix
            ./my/users/streaming/streaming.nix
            ./my/users/dev/development.nix
            ./my/users/ai/ai.nix

            # Graphical
            ./my/graphical/graphical.nix
            ./my/graphical/hyprland.nix

            # System
            ./my/system/core.nix
            ./my/system/kernel.nix

            # Environment
            ./my/environment/environment.nix

            # Security
            ./my/security/security.nix
            ./my/security/yubikey.nix

            # Audio
            ./my/audio/audio.nix

            # Video
            ./my/video/virtual.nix

            # Performance
            ./my/performance/performance.nix

            # Storage
            ./my/storage/impermanence/impermanence.nix

            # Themes
            ./my/themes/themes.nix

            # Infrastructure
            ./my/infra/k3s/k3s.nix
            ./my/infra/github-runner/github-runner.nix

            # Apps (user-level)
            ./my/users/apps/browsers/brave.nix
            ./my/users/apps/browsers/firefox.nix
            ./my/users/apps/terminals/wezterm.nix
            ./my/users/apps/terminals/kitty.nix
            ./my/users/apps/terminals/ghostty.nix
            ./my/users/apps/terminals/alacritty.nix
            ./my/users/apps/terminals/warp.nix
            ./my/users/apps/editors/helix.nix
            ./my/users/apps/editors/marktext.nix
            ./my/users/apps/shells/bash.nix
            ./my/users/apps/shells/fish.nix
            ./my/users/apps/prompts/starship.nix
            ./my/users/apps/fileManagers/mc.nix
            ./my/users/apps/fileManagers/yazi.nix
            ./my/users/apps/multiplexers/zellij.nix
            ./my/users/apps/multiplexers/tmux.nix
            ./my/users/apps/viewers/bat.nix
            ./my/users/apps/viewers/feh.nix
            ./my/users/apps/fileUtils/lsd.nix
            ./my/users/apps/sysinfo/btop.nix
            ./my/users/apps/sysinfo/neofetch.nix
            ./my/users/apps/sysinfo/fastfetch.nix
            ./my/users/apps/visualizers/cava.nix
            ./my/users/apps/launchers/walker.nix
            ./my/users/apps/sync/rclone.nix
            ./my/users/apps/utils/calculator.nix
            ./my/users/apps/utils/imagemagick.nix
            ./my/users/apps/dev/direnv.nix
            ./my/users/apps/dev/devenv.nix
            ./my/users/apps/dev/github-desktop.nix
            ./my/users/apps/dev/kdiff3.nix
            ./my/users/apps/dev/jq.nix
            ./my/users/apps/dev/vscode.nix
            ./my/users/apps/media/pipewire-tools.nix
            ./my/users/apps/media/musikcube.nix
            ./my/users/apps/media/audacious.nix
            ./my/users/apps/media/audio-utils.nix
            ./my/users/apps/communication/element.nix
            ./my/users/apps/communication/signal.nix
            ./my/users/apps/communication/slack.nix
            ./my/users/apps/finance/cointop.nix
            ./my/users/apps/art/mypaint.nix
            ./my/users/apps/network/termscp.nix
            ./my/users/apps/fun/pipes.nix
            ./my/users/apps/git.nix
            ./my/users/apps/jujutsu.nix
            ./my/users/apps/ssh.nix
            ./my/users/apps/xdg.nix

            # Hardware
            ./my/hardware/cpu/amd.nix
            ./my/hardware/cpu/intel.nix
            ./my/hardware/gpu/amd.nix
            ./my/hardware/gpu/nvidia.nix
            ./my/hardware/bluetooth/realtek.nix
            ./my/hardware/storage
            ./my/hardware/usb
            ./my/hardware/memory
            ./my/hardware/cooling/nzxt/kraken-elite-rgb/elite-240-rgb.nix
            ./my/hardware/motherboards/gigabyte/x870e-aorus-elite-wifi7
            ./my/hardware/laptops/lenovo/legion-16irx8h
            ./my/hardware/peripherals
            ./my/hardware/boot/uefi.nix
            ./my/hardware/boot/dual-boot.nix
          ];

          options.my = {
            # Hostname configuration (deprecated - use my.system.hostname instead)
            hostname = lib.mkOption {
              type = lib.types.str;
              description = "System hostname";
            };

            # System-level configuration
            system = lib.mkOption {
              description = "System-level configuration";
              default = { };
              type = lib.types.submodule {
                options = {
                  hostname = lib.mkOption {
                    type = lib.types.nullOr lib.types.str;
                    default = null;
                    description = "System hostname (if null, uses my.hostname for backwards compatibility)";
                  };

                  kernel = lib.mkOption {
                    type = lib.types.nullOr lib.types.package;
                    default = null;
                    description = "Kernel package override (e.g., pkgs.linuxPackages_latest, pkgs.linuxPackages_6_12). If null, uses hardware module default (typically latest).";
                  };

                  architecture = lib.mkOption {
                    type = lib.types.nullOr (lib.types.enum [ "x86_64-linux" "aarch64-linux" ]);
                    default = null;
                    description = "System architecture (auto-detected from hardware if null)";
                  };

                  enable = lib.mkEnableOption "core system utilities (console, nix, boot configuration, plymouth)";
                };
              };
            };

            # Security stack (flattened from my.features.security)
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

            # Environment configuration (flattened from my.features.environment)
            environment = lib.mkOption {
              description = "Environment variables, XDG, locale, timezone";
              default = { };
              type = lib.types.submodule {
                options = {
                  enable = lib.mkEnableOption "environment configuration (variables, XDG, locale)";

                  editor = lib.mkOption {
                    type = lib.types.package;
                    default = pkgs.helix;
                    description = "Default text editor package (mynixos default: helix)";
                  };

                  browser = lib.mkOption {
                    type = lib.types.package;
                    default = pkgs.brave;
                    description = "Default web browser package (mynixos default: brave)";
                  };

                  timezone = lib.mkOption {
                    type = lib.types.str;
                    default = "America/Denver";
                    description = "System timezone (mynixos default: America/Denver)";
                  };

                  locale = lib.mkOption {
                    type = lib.types.str;
                    default = "en_US.UTF-8";
                    description = "System locale (mynixos default: en_US.UTF-8)";
                  };

                  keyboardLayout = lib.mkOption {
                    type = lib.types.str;
                    default = "us";
                    description = "Keyboard layout (mynixos default: us)";
                  };

                  xdg = {
                    enable = lib.mkEnableOption "XDG portal support for Wayland";
                  };

                  motd = lib.mkOption {
                    description = "Message of the day configuration";
                    default = { };
                    type = lib.types.submodule {
                      options = {
                        enable = lib.mkEnableOption "message of the day";

                        content = lib.mkOption {
                          type = lib.types.str;
                          default = "";
                          description = "MOTD content to display on login";
                        };
                      };
                    };
                  };
                };
              };
            };

            # Performance tuning (flattened from my.features.performance)
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

            # AI stack - system-level Ollama service (flattened from my.features.ai)
            ai = lib.mkOption {
              description = "AI infrastructure (Ollama service with ROCm support)";
              default = { };
              type = lib.types.submodule {
                options = {
                  enable = lib.mkEnableOption "AI infrastructure with Ollama and ROCm support";

                  rocmGfxVersion = lib.mkOption {
                    type = lib.types.str;
                    default = "11.0.2";
                    description = "ROCm GFX version override for AMD GPU compatibility (opinionated default: 11.0.2 for RDNA3)";
                  };
                };
              };
            };

            # Video namespace - virtual camera support
            video = lib.mkOption {
              description = "Video device configuration";
              default = { };
              type = lib.types.submodule {
                options = {
                  virtual = lib.mkOption {
                    description = "Virtual camera devices (v4l2loopback)";
                    default = { };
                    type = lib.types.submodule {
                      options = {
                        enable = lib.mkOption {
                          type = lib.types.bool;
                          default = false;
                          description = "Enable v4l2loopback kernel module for virtual webcam (auto-enabled by user streaming)";
                        };
                      };
                    };
                  };
                };
              };
            };

            # Infrastructure namespace
            infra = lib.mkOption {
              description = "Infrastructure services";
              default = { };
              type = lib.types.submodule {
                options = {
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

                  github-runner = lib.mkOption {
                    description = "GitHub Actions Runner Controller stack (requires k3s)";
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
                };
              };
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

                  motherboards = {
                    gigabyte = {
                      x870e-aorus-elite-wifi7 = {
                        enable = lib.mkEnableOption "Gigabyte X870E AORUS Elite WiFi7 motherboard";

                        bluetooth = {
                          enable = lib.mkOption {
                            type = lib.types.bool;
                            default = true;
                            description = "Enable bluetooth hardware";
                          };
                        };

                        networking = {
                          enable = lib.mkOption {
                            type = lib.types.bool;
                            default = true;
                            description = "Enable network hardware";
                          };

                          useDHCP = lib.mkOption {
                            type = lib.types.bool;
                            default = true;
                            description = "Use DHCP for network configuration";
                          };

                          wireless = {
                            enable = lib.mkOption {
                              type = lib.types.bool;
                              default = false;
                              description = "Enable wireless networking (use NetworkManager instead)";
                            };

                            useDHCP = lib.mkOption {
                              type = lib.types.bool;
                              default = true;
                              description = "Use DHCP for wireless interface";
                            };
                          };
                        };

                        storage = {
                          nvme = {
                            enable = lib.mkOption {
                              type = lib.types.bool;
                              default = true;
                              description = "Enable NVMe storage support";
                            };
                          };

                          sata = {
                            enable = lib.mkOption {
                              type = lib.types.bool;
                              default = false;
                              description = "Enable SATA/AHCI storage support";
                            };
                          };

                          usb = {
                            enable = lib.mkOption {
                              type = lib.types.bool;
                              default = true;
                              description = "Enable USB storage support";
                            };
                          };
                        };

                        usb = {
                          xhci = {
                            enable = lib.mkOption {
                              type = lib.types.bool;
                              default = true;
                              description = "Enable xHCI (USB 3.0) support";
                            };
                          };

                          thunderbolt = {
                            enable = lib.mkOption {
                              type = lib.types.bool;
                              default = true;
                              description = "Enable Thunderbolt support";
                            };
                          };

                          hid = {
                            enable = lib.mkOption {
                              type = lib.types.bool;
                              default = true;
                              description = "Enable USB HID support";
                            };
                          };
                        };

                        memory = {
                          optimization = {
                            enable = lib.mkOption {
                              type = lib.types.bool;
                              default = true;
                              description = "Enable memory optimizations";
                            };
                          };
                        };
                      };
                    };
                  };

                  laptops = {
                    lenovo = {
                      legion-16irx8h = {
                        enable = lib.mkEnableOption "Lenovo Legion 16IRX8H laptop";
                      };
                    };
                  };

                  cooling = {
                    nzxt = {
                      kraken-elite-rgb = {
                        elite-240-rgb = {
                          enable = lib.mkEnableOption "NZXT Kraken Elite 240 RGB AIO cooler";

                          lcd = {
                            enable = lib.mkOption {
                              type = lib.types.bool;
                              default = true;
                              description = "Enable LCD screen support";
                            };

                            brightness = lib.mkOption {
                              type = lib.types.int;
                              default = 100;
                              description = "LCD screen brightness (0-100)";
                            };
                          };

                          rgb = {
                            enable = lib.mkOption {
                              type = lib.types.bool;
                              default = true;
                              description = "Enable RGB ring around LCD screen";
                            };
                          };

                          liquidctl = {
                            enable = lib.mkOption {
                              type = lib.types.bool;
                              default = true;
                              description = "Install liquidctl CLI tool";
                            };

                            autoInitialize = lib.mkOption {
                              type = lib.types.bool;
                              default = false;
                              description = "Automatically run liquidctl initialize on boot";
                            };
                          };

                          monitoring = {
                            enable = lib.mkOption {
                              type = lib.types.bool;
                              default = true;
                              description = "Install lm_sensors for monitoring";
                            };
                          };
                        };
                      };
                    };
                  };

                  peripherals = {
                    elgato = {
                      streamdeck = {
                        enable = lib.mkOption {
                          type = lib.types.bool;
                          default = false;
                          description = ''
                            Enable Elgato Stream Deck support (all models).

                            Provides udev rules, streamdeck-ui package, and Qt/Wayland integration
                            for Stream Deck programmable macro pads (Original, Mini, XL, V2, MK.2, Plus).

                            Vendor: Elgato Systems (0fd9)
                            Device type: USB HID programmable control surface
                          '';
                        };
                      };
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
                    description = "DEPRECATED: Use my.users.<name>.github.username instead. GitHub username for this user.";
                  };

                  github = lib.mkOption {
                    description = "GitHub configuration for this user";
                    default = { };
                    type = lib.types.submodule {
                      options = {
                        username = lib.mkOption {
                          type = lib.types.nullOr lib.types.str;
                          default = null;
                          description = "GitHub username for this user";
                          example = "i-am-logger";
                        };

                        repositories = lib.mkOption {
                          type = lib.types.listOf lib.types.str;
                          default = [ ];
                          description = "Repository names to create GitHub Actions runners for (requires my.infra.github-runner.enable)";
                          example = [ "dotfiles" "mynixos" "website" ];
                        };
                      };
                    };
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
                    description = "Default editor command (e.g., 'hx', 'vim', 'nvim'). Defaults to 'hx' from mynixos. DEPRECATED: Use environment.editor instead.";
                  };

                  browser = lib.mkOption {
                    type = lib.types.nullOr lib.types.str;
                    default = null;
                    description = "Default browser command (e.g., 'brave', 'firefox', 'chromium'). Defaults to 'brave' from mynixos. DEPRECATED: Use environment.browser instead.";
                  };

                  # User environment configuration (editor, browser packages)
                  environment = lib.mkOption {
                    description = "User-level environment configuration (editor, browser, etc)";
                    default = { };
                    type = lib.types.submodule {
                      options = {
                        editor = lib.mkOption {
                          type = lib.types.package;
                          default = pkgs.helix;
                          description = "Default editor package (opinionated default: helix)";
                        };

                        browser = lib.mkOption {
                          type = lib.types.package;
                          default = pkgs.brave;
                          description = "Default browser package (opinionated default: brave)";
                        };
                      };
                    };
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

                  # User-level feature booleans (flattened from my.users.<name>.features)
                  graphical = lib.mkOption {
                    type = lib.types.bool;
                    default = false;
                    description = "Enable graphical environment for this user (auto-enables Hyprland + greetd system services)";
                  };

                  dev = lib.mkOption {
                    type = lib.types.bool;
                    default = false;
                    description = "Enable development tools for this user (auto-enables Docker, binfmt)";
                  };

                  streaming = lib.mkOption {
                    type = lib.types.bool;
                    default = false;
                    description = "Enable streaming tools for this user (OBS Studio, auto-enables v4l2loopback)";
                  };

                  ai = lib.mkOption {
                    type = lib.types.bool;
                    default = false;
                    description = "Enable AI tools for this user (MCP servers, requires system-level my.ai.enable)";
                  };

                  docker = {
                    enable = lib.mkOption {
                      type = lib.types.bool;
                      default = false;
                      description = "Enable Docker with rootless support (auto-enabled by dev = true)";
                    };
                  };

                  # Webapps submodule (flattened from my.users.<name>.features.webapps)
                  webapps = lib.mkOption {
                    description = "Browser-based web applications (per-user)";
                    default = { };
                    type = lib.types.submodule {
                      options = {
                        enable = lib.mkOption {
                          type = lib.types.bool;
                          default = true;
                          description = "Enable webapps for this user (opinionated default: enabled)";
                        };

                        # Individual webapps - mynixos opinionated defaults
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

                        # Electron apps (disabled by default)
                        slack = lib.mkOption { type = lib.types.bool; default = false; description = "Slack (Electron)"; };
                        signal = lib.mkOption { type = lib.types.bool; default = false; description = "Signal (Electron)"; };

                        # Password managers (disabled by default)
                        onePassword = lib.mkOption { type = lib.types.bool; default = false; description = "1Password"; };
                      };
                    };
                  };

                  # Hyprland submodule (flattened from my.users.<name>.features.hyprland)
                  hyprland = lib.mkOption {
                    description = "User-specific Hyprland configuration";
                    default = { };
                    type = lib.types.submodule {
                      options = {
                        enable = lib.mkOption {
                          type = lib.types.bool;
                          default = true;
                          description = "Enable user-specific Hyprland config (opinionated default: enabled when user graphical = true)";
                        };

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
                    };
                  };


                  # Apps namespace (per-user application preferences)
                  apps = lib.mkOption {
                    type = lib.types.submodule {
                      options = {
                        communication = {
                          element = lib.mkEnableOption "Element Matrix client";
                          signal = lib.mkEnableOption "Signal Desktop messenger";
                          slack = lib.mkEnableOption "Slack communication tool";
                        };

                        terminals = {
                          wezterm = lib.mkOption {
                            type = lib.types.bool;
                            default = true;
                            description = "WezTerm terminal (opinionated default: enabled)";
                          };
                          kitty = lib.mkEnableOption "Kitty terminal";
                          ghostty = lib.mkEnableOption "Ghostty terminal";
                        };

                        shells = {
                          bash = lib.mkEnableOption "Bash shell";
                          fish = lib.mkEnableOption "Fish shell";
                        };

                        prompts = {
                          starship = lib.mkEnableOption "Starship prompt";
                        };

                        browsers = {
                          brave = lib.mkOption {
                            type = lib.types.bool;
                            default = true;
                            description = "Brave browser (opinionated default: enabled)";
                          };
                          firefox = lib.mkEnableOption "Firefox browser";
                        };

                        editors = {
                          helix = lib.mkOption {
                            type = lib.types.bool;
                            default = true;
                            description = "Helix editor (opinionated default: enabled)";
                          };
                          marktext = lib.mkEnableOption "MarkText markdown editor";
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

                        visualizers = {
                          cava = lib.mkEnableOption "cava audio visualizer";
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
                          vscode = lib.mkOption {
                            type = lib.types.bool;
                            default = true;
                            description = "Visual Studio Code editor (opinionated default: enabled)";
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
                      };
                    };
                    default = { };
                    description = "Per-user application configurations";
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
                          type = lib.types.bool;
                          default = false;
                          description = "Create ~/.flake symlink pointing to /etc/nixos for all users (auto-detected from my.users)";
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
