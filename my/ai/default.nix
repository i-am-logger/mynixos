{ activeUsers, config, lib, pkgs, ... }:

with lib;

let
  cfg = config.my.ai;
  inherit (config.my.hardware) gpu;# "amd" | "nvidia" | "intel" | null
  # Acceleration: explicit override > auto-detect from hardware GPU
  acceleration =
    if cfg.ollama.acceleration != "auto" then cfg.ollama.acceleration
    else if gpu == "amd" then "rocm"
    else if gpu == "nvidia" then "cuda"
    else "cpu";
  isRocm = acceleration == "rocm";
  isCuda = acceleration == "cuda";

  # Auto-enable AI when any user has ai.enable = true
  anyUserAI = any (userCfg: userCfg.ai.enable or false) (attrValues config.my.users);

  # mynixos opinionated defaults for AI features
  defaults = {
    mcpServers = false;
  };

  # GitHub MCP Server package
  mcp-github = pkgs.writeShellScriptBin "mcp-github" ''
    set -e
    export NODE_OPTIONS="--no-warnings"
    export MCP_TRANSPORT_TYPE="stdio"
    export MCP_LOG_LEVEL="info"
    export PATH="${pkgs.github-mcp-server}/bin:${pkgs.git}/bin:${pkgs.gh}/bin:$PATH"

    export GITHUB_PERSONAL_ACCESS_TOKEN=$(${pkgs.gh}/bin/gh auth token 2>/dev/null || echo "")

    if [ -z "$GITHUB_PERSONAL_ACCESS_TOKEN" ]; then
      echo "Warning: No GitHub token found. Please run 'gh auth login' first." >&2
      echo "Some functionality may be limited without authentication." >&2
    fi

    ${pkgs.github-mcp-server}/bin/github-mcp-server "$@" || {
      echo "Error: Failed to run github-mcp-server" >&2
      echo "Please check your GitHub authentication and network connection" >&2
      exit 1
    }
  '';

  mcp-packages = {
    inherit mcp-github;
  };
in
{
  config = mkMerge [
    # Auto-derive system AI flag from user config (overridable)
    { my.ai.enable = mkDefault anyUserAI; }

    (mkIf cfg.enable (mkMerge [
      # Ollama service — GPU-agnostic (auto-detects from my.hardware.gpu)
      (mkIf cfg.ollama.enable {
        services.ollama = {
          enable = true;
          package =
            if isCuda then pkgs.ollama-cuda
            else if isRocm then pkgs.ollama-rocm
            else pkgs.ollama;
          home = "/var/lib/ollama";
          models = "/var/lib/ollama/models";
          loadModels = cfg.ollama.models;
        };

        environment.variables = {
          OLLAMA_HOST = "127.0.0.1:11434";
          OLLAMA_NUM_PARALLEL = "1";
          OLLAMA_MAX_LOADED_MODELS = "1";
          OLLAMA_FLASH_ATTENTION = "true";
        };
      })

      # ROCm-specific configuration (AMD GPU)
      (mkIf (cfg.ollama.enable && isRocm) {
        environment.systemPackages = with pkgs; [
          rocmPackages.rocm-runtime
          rocmPackages.rocm-device-libs
          rocmPackages.rocm-smi
          rocmPackages.hipify
        ];

        environment.variables = {
          HSA_OVERRIDE_GFX_VERSION = cfg.ollama.rocmGfxVersion;
          ROC_ENABLE_PRE_VEGA = "1";
        };

        systemd.services.ollama.environment = {
          HSA_OVERRIDE_GFX_VERSION = cfg.ollama.rocmGfxVersion;
          ROC_ENABLE_PRE_VEGA = "1";
        };
      })

      # Optional web UI
      (mkIf (cfg.ollama.enable && cfg.ollama.webUI) {
        services.nextjs-ollama-llm-ui.enable = true;
      })

      # MCP Servers — per-user configuration
      {
        home-manager.users = mapAttrs
          (_name: userCfg:
            let
              userAI = userCfg.ai or { };
            in
            mkIf (userAI.mcpServers or defaults.mcpServers) {
              home.packages = lib.attrValues mcp-packages;
            })
          (activeUsers config.my.users);
      }

      # Persistence
      {
        my.system.persistence.features = {
          systemDirectories = [
            "/var/lib/private"
          ];
        };
      }
    ]))
  ];
}
