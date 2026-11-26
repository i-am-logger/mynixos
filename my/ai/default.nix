{ activeUsers, config, lib, pkgs, ... }:

with lib;

let
  cfg = config.my.ai;
  inherit (config.my.hardware) gpu;# "amd" | "nvidia" | "intel" | null
  # Acceleration: explicit override > the GPU vendor (CUDA on NVIDIA, ROCm on
  # AMD) > CPU. Only the consumer selects its CUDA build; nothing sets a
  # global cudaSupport that would rebuild every package with CUDA.
  acceleration =
    if cfg.ollama.acceleration != "auto" then cfg.ollama.acceleration
    else if gpu == "nvidia" then "cuda"
    else if gpu == "amd" then "rocm"
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
      # No OpenCV in the system path: a library is linked by the software that
      # needs it (or a project's devenv), never installed globally. Its CUDA
      # build is the consumer's choice, never a global flag.

      # Ollama service — package variant follows `acceleration`: CUDA on an
      # NVIDIA GPU, ROCm on an AMD GPU, else CPU. CUDA's libraries are under
      # NVIDIA's CUDA EULA, accepted only on that branch.
      (mkIf cfg.ollama.enable {
        my.system.allowedUnfreeLicenses = mkIf isCuda [ "CUDA EULA" ];

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

        # ollama runs as DynamicUser, so its state lives in /var/lib/private/ollama
        # (persisted via the /var/lib/private bind mount below). A public
        # /var/lib/ollama directory left over from a static-user setup makes systemd
        # try to migrate it into the private path with rename(2), which fails EXDEV
        # across the impermanence bind-mount boundary (status=238/STATE_DIRECTORY).
        # Drop the stale public directory so systemd creates the private state and
        # symlink cleanly. A no-op once /var/lib/ollama is the expected symlink.
        systemd.services.ollama-statedir-cleanup = {
          description = "Remove stale public ollama state dir (DynamicUser migration guard)";
          before = [ "ollama.service" ];
          requiredBy = [ "ollama.service" ];
          serviceConfig.Type = "oneshot";
          script = ''
            if [ -d /var/lib/ollama ] && [ ! -L /var/lib/ollama ]; then
              ${pkgs.coreutils}/bin/rm -rf /var/lib/ollama
            fi
          '';
        };
      })

      # ROCm-specific configuration (AMD GPU)
      (mkIf (cfg.ollama.enable && isRocm) {
        environment.systemPackages = with pkgs; [
          rocmPackages.rocm-smi
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
