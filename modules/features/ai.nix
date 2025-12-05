{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.my.features.ai;

  # GitHub MCP Server package (from github.com/mcp/github/github-mcp-server)
  mcp-github = pkgs.writeShellScriptBin "mcp-github" ''
    set -e
    export NODE_OPTIONS="--no-warnings"
    export MCP_TRANSPORT_TYPE="stdio"
    export MCP_LOG_LEVEL="info"
    export PATH="${pkgs.github-mcp-server}/bin:${pkgs.git}/bin:${pkgs.gh}/bin:$PATH"

    # Use GitHub personal access token from gh auth
    export GITHUB_PERSONAL_ACCESS_TOKEN=$(${pkgs.gh}/bin/gh auth token 2>/dev/null || echo "")

    if [ -z "$GITHUB_PERSONAL_ACCESS_TOKEN" ]; then
      echo "Warning: No GitHub token found. Please run 'gh auth login' first."
      echo "Some functionality may be limited without authentication."
    fi

    # Run the Nix-installed github-mcp-server
    ${pkgs.github-mcp-server}/bin/github-mcp-server "$@" || {
      echo "Error: Failed to run github-mcp-server"
      echo "Please check your GitHub authentication and network connection"
      exit 1
    }
  '';

  # MCP Server packages
  mcp-packages = {
    # rs-mcp-filesystem = pkgs.callPackage ./servers/filesystem.nix { };
    # rs-mcp-git = pkgs.callPackage ./servers/git.nix { };
    # rs-mcp-gitingest = pkgs.callPackage ./servers/gitingest.nix { };
    # rs-mcp-github = pkgs.callPackage ./servers/github.nix { };
    inherit mcp-github;
    # rs-mcp-chat = pkgs.callPackage ./servers/chat.nix { };
    # rs-mcp-pulumi = pkgs.callPackage ./servers/pulumi.nix { };
    # rs-mcp-fetch = pkgs.callPackage ./servers/fetch.nix { };
    # rs-mcp-playwright = pkgs.callPackage ./servers/playwright.nix { };
    # rs-mcp-time = pkgs.callPackage ./servers/time.nix { };
    # rs-mcp-sequentialthinking = pkgs.callPackage ./servers/sequentialthinking.nix { };
    # rs-mcp-context7 = pkgs.callPackage ./servers/context7.nix { };
    # rs-mcp-youtube-transcript = pkgs.callPackage ./servers/youtube-transcript.nix { };
  };
in
{
  config = mkIf cfg.enable (mkMerge [
    # Base AI configuration - Ollama with ROCm support (opinionated)
    {
      # ROCm packages for AMD GPU acceleration
      environment.systemPackages = with pkgs; [
        rocmPackages.rocm-runtime
        rocmPackages.rocm-device-libs
        rocmPackages.rocm-smi
        rocmPackages.hipify
      ];

      # Environment variables for ROCm and Ollama
      environment.variables = {
        HSA_OVERRIDE_GFX_VERSION = cfg.rocmGfxVersion; # AMD GPU override for ROCm compatibility
        ROC_ENABLE_PRE_VEGA = "1"; # Enable older AMD GPU support
        OLLAMA_HOST = "127.0.0.1:11434";
        OLLAMA_NUM_PARALLEL = "1";
        OLLAMA_MAX_LOADED_MODELS = "1";
        OLLAMA_FLASH_ATTENTION = "true";
      };

      # Ollama service with ROCm acceleration
      services.ollama = {
        enable = true;
        package = pkgs.ollama-rocm;
        acceleration = "rocm";
        user = "ollama";
        group = "ollama";
        home = "/var/lib/ollama";
        models = "/var/lib/ollama/models";
        loadModels = [
          "qwen2.5-coder:32b"
          "llama3.3:70b"
        ];
      };

      # Ensure ollama user/group exist
      users.users.ollama = {
        isSystemUser = true;
        group = "ollama";
        home = "/var/lib/ollama";
        createHome = true;
      };

      users.groups.ollama = { };

      # Override systemd service to add ROCm environment variables
      systemd.services.ollama.environment = {
        HSA_OVERRIDE_GFX_VERSION = cfg.rocmGfxVersion;
        ROC_ENABLE_PRE_VEGA = "1";
      };
    }

    # MCP Servers (Model Context Protocol)
    (mkIf cfg.mcpServers.enable {
      environment.systemPackages = lib.attrValues mcp-packages;
    })
  ]);
}
