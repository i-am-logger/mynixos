{
  description = "mynixos - A typed functional DSL for NixOS configuration";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs, ... }:
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

      # Main NixOS module providing the `my.*` namespace
      nixosModules.default = { config, lib, pkgs, ... }:
        let
          cfg = config.my;
        in
        {
          imports = [
            # Features
            ./modules/features/users.nix
            ./modules/features/security.nix
            ./modules/features/graphical.nix
            ./modules/features/github-runner.nix
            ./modules/features/ai.nix
            ./modules/features/webapps.nix
            ./modules/features/streaming.nix
            ./modules/features/development.nix
            ./modules/features/system.nix

            # Apps
            ./modules/apps/browsers/brave.nix
            ./modules/apps/terminals/wezterm.nix
            ./modules/apps/terminals/kitty.nix
            ./modules/apps/terminals/ghostty.nix
            ./modules/apps/editors/helix.nix
            ./modules/apps/shells/fish.nix
            ./modules/apps/prompts/starship.nix
            ./modules/apps/fileManagers/mc.nix
            ./modules/apps/multiplexers/zellij.nix
            ./modules/apps/windowManagers/hyprland.nix

            # Hardware
            ./modules/hardware/cpu/amd.nix
            ./modules/hardware/cpu/intel.nix
            ./modules/hardware/gpu/amd.nix
            ./modules/hardware/gpu/nvidia.nix
            ./modules/hardware/audio/realtek.nix
            ./modules/hardware/bluetooth/realtek.nix
            ./modules/hardware/boot/uefi.nix
            ./modules/hardware/network/default.nix
            ./modules/hardware/motherboards/gigabyte-x870e.nix
            ./modules/hardware/motherboards/lenovo-legion-16irx8h.nix

            # Infrastructure
            ./modules/infra/services/k3s.nix
          ];

          options.my = {
            # Features namespace
            features = lib.mkOption {
              type = lib.types.submodule {
                options = {
                  # Users feature
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
                          type = lib.types.str;
                          description = "Full name for git, etc";
                        };

                        email = lib.mkOption {
                          type = lib.types.str;
                          description = "Email for git, etc";
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

                        editor = lib.mkOption {
                          type = lib.types.nullOr lib.types.str;
                          default = null;
                          description = "Default editor (helix, vim, neovim)";
                        };

                        passkey = lib.mkOption {
                          type = lib.types.nullOr (lib.types.attrsOf lib.types.anything);
                          default = null;
                          description = "Passkey configuration (yubikey, solokey, nitrokey)";
                        };
                      };
                    }));
                  };

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

                        warp = {
                          enable = lib.mkEnableOption "warp terminal";
                          preview = lib.mkOption {
                            type = lib.types.bool;
                            default = false;
                            description = "Use preview version";
                          };
                        };

                        vscode = {
                          enable = lib.mkEnableOption "Visual Studio Code";
                        };

                        browser = {
                          enable = lib.mkEnableOption "browser (brave)";
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
                          description = "Enable GPU passthrough to runners";
                        };

                        gpuVendor = lib.mkOption {
                          type = lib.types.enum [ "amd" "nvidia" ];
                          default = "amd";
                          description = "GPU vendor (amd or nvidia)";
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

                        mcpServers = {
                          enable = lib.mkEnableOption "Model Context Protocol servers";
                        };
                      };
                    };
                  };

                  # Webapps feature
                  webapps = lib.mkOption {
                    description = "Browser-based and Electron applications";
                    default = { };
                    type = lib.types.submodule {
                      options = {
                        enable = lib.mkEnableOption "webapps stack";

                        electronApps = {
                          enable = lib.mkEnableOption "Electron apps (Slack, Signal)";
                        };

                        onePassword = {
                          enable = lib.mkEnableOption "1Password password manager";
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
                          enable = lib.mkEnableOption "OBS Studio with plugins";
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
                          enable = lib.mkEnableOption "Docker with rootless support";
                        };

                        direnv = {
                          enable = lib.mkEnableOption "direnv environment manager";
                        };

                        binfmt = {
                          enable = lib.mkEnableOption "binfmt emulation (aarch64-linux)";
                        };

                        appimage = {
                          enable = lib.mkEnableOption "AppImage support";
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

            # Apps namespace
            apps = lib.mkOption {
              type = lib.types.submodule {
                options = {
                  browsers = {
                    brave = lib.mkEnableOption "Brave browser";
                    firefox = lib.mkEnableOption "Firefox browser";
                  };

                  terminals = {
                    wezterm = lib.mkEnableOption "WezTerm";
                    kitty = lib.mkEnableOption "Kitty";
                    ghostty = lib.mkEnableOption "Ghostty";
                  };

                  editors = {
                    helix = lib.mkEnableOption "Helix editor";
                    neovim = lib.mkEnableOption "Neovim";
                  };

                  windowManagers = {
                    hyprland = lib.mkEnableOption "Hyprland";
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
          };

          config = {
            # Placeholder - actual implementations will be in separate module files
            # that import based on my.* options
          };
        };

      # Export library functions
      lib = {
        inherit yubikey solokey nitrokey;
      };
    };
}
