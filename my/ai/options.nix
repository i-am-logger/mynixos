{ lib, ... }:

{
  ai = lib.mkOption {
    description = "AI infrastructure (Ollama, OpenClaw, MCP servers)";
    default = { };
    type = lib.types.submodule {
      options = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Auto-set to true when any user has ai.enable = true (managed by mynixos)";
        };

        ollama = {
          enable = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "Enable Ollama local LLM service (disable if using claude-code-proxy only)";
          };

          acceleration = lib.mkOption {
            type = lib.types.enum [ "rocm" "cuda" "cpu" "auto" ];
            default = "auto";
            description = "GPU acceleration backend. auto = detect from my.hardware.gpu, cpu = no GPU acceleration";
          };

          models = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [ ];
            description = "Models to auto-pull on service start";
          };

          webUI = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = "Enable nextjs-ollama-llm-ui web interface";
          };

          rocmGfxVersion = lib.mkOption {
            type = lib.types.str;
            default = "11.0.2";
            description = "ROCm GFX version override for AMD GPU compatibility (RDNA3 default)";
          };
        };

        claudeCodeProxy = {
          enable = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = "OpenAI-compatible proxy wrapping Claude Code CLI (spawns claude --print as subprocess, does not extract OAuth tokens)";
          };

          port = lib.mkOption {
            type = lib.types.port;
            default = 8080;
            description = "Proxy listen port";
          };

          model = lib.mkOption {
            type = lib.types.str;
            default = "sonnet";
            description = "Default Claude model (haiku/sonnet/opus)";
          };

          apiKey = lib.mkOption {
            type = lib.types.str;
            default = "claude-code-proxy-local";
            description = "Bearer token for proxy authentication";
          };
        };

        openclaw = {
          enable = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = "Enable OpenClaw gateway service";
          };

          port = lib.mkOption {
            type = lib.types.port;
            default = 18789;
            description = "Gateway port";
          };

          bind = lib.mkOption {
            type = lib.types.enum [ "loopback" "lan" ];
            default = "loopback";
            description = "Bind mode";
          };

          ollamaModel = lib.mkOption {
            type = lib.types.str;
            default = "qwen2.5:14b";
            description = "Default Ollama model for inference";
          };

          gatewayToken = lib.mkOption {
            type = lib.types.str;
            default = "openclaw-local-token";
            description = "Gateway auth token (shared between service and CLI users)";
          };

          signal = {
            enable = lib.mkEnableOption "Signal channel";

            account = lib.mkOption {
              type = lib.types.str;
              default = "";
              description = "Signal phone number (E.164 format)";
            };

            allowFrom = lib.mkOption {
              type = lib.types.listOf lib.types.str;
              default = [ ];
              description = "Phone numbers allowed to message (E.164 format)";
            };
          };

          extraConfig = lib.mkOption {
            type = lib.types.attrs;
            default = { };
            description = "Additional openclaw.json configuration (merged with generated config)";
          };
        };
      };
    };
  };
}
