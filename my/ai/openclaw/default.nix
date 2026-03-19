{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.my.ai.openclaw;
  proxyCfg = config.my.ai.claudeProxy;
  useClaudeProxy = proxyCfg.enable;

  # Auto-detect provider: claude-proxy if enabled, otherwise ollama
  modelProvider =
    if useClaudeProxy then {
      name = "claude-proxy";
      baseUrl = "http://127.0.0.1:${toString proxyCfg.port}/v1";
      api = "openai-completions";
      inherit (proxyCfg) apiKey;
      modelId = proxyCfg.model;
      modelName = proxyCfg.model;
    } else {
      name = "ollama";
      baseUrl = "http://127.0.0.1:11434";
      api = null;
      apiKey = null;
      modelId = cfg.ollamaModel;
      modelName = cfg.ollamaModel;
    };

  openclaw = pkgs.buildNpmPackage rec {
    pname = "openclaw";
    version = "2026.3.13";

    src = pkgs.fetchurl {
      url = "https://registry.npmjs.org/openclaw/-/openclaw-${version}.tgz";
      hash = "sha256-ZxHZ+MTxK9vc1QkOaGXi7hQbjNo+qo8gJZMEQGog6Wo=";
    };

    sourceRoot = "package";

    postPatch = ''
      cp ${./openclaw-package-lock.json} package-lock.json
    '';

    npmDepsHash = "sha256-XWDzeIUTv/N79w/Ij8Fdaj+xw84bi+HXB51sG8Jgwo8=";

    nodejs = pkgs.nodejs_22;
    makeCacheWritable = true;
    npmFlags = [
      "--legacy-peer-deps"
      "--ignore-scripts"
    ];
    dontNpmBuild = true;

    postInstall = ''
      cd $out/lib/node_modules/openclaw
      npm rebuild --ignore-scripts 2>/dev/null || true
      cd -
      mkdir -p $out/bin
      makeWrapper ${pkgs.nodejs_22}/bin/node $out/bin/openclaw \
        --add-flags "$out/lib/node_modules/openclaw/openclaw.mjs"
    '';

    nativeBuildInputs = with pkgs; [
      makeWrapper
      python3
    ];

    meta = {
      description = "Multi-channel personal AI assistant";
      mainProgram = "openclaw";
    };
  };

  stateDir = "/var/lib/openclaw";

  openclawConfig = builtins.toJSON (
    lib.recursiveUpdate
      (
        {
          gateway = {
            inherit (cfg) port;
            inherit (cfg) bind;
            mode = "local";
            auth = {
              mode = "token";
              token = cfg.gatewayToken;
            };
          };
          models = {
            providers = {
              ${modelProvider.name} = {
                inherit (modelProvider) baseUrl;
                models = [
                  {
                    id = modelProvider.modelId;
                    name = modelProvider.modelName;
                  }
                ];
              } // lib.optionalAttrs (modelProvider.apiKey != null) {
                inherit (modelProvider) apiKey;
              } // lib.optionalAttrs (modelProvider.api != null) {
                inherit (modelProvider) api;
              };
            };
          };
        }
        // lib.optionalAttrs cfg.signal.enable {
          channels = {
            signal =
              {
                inherit (cfg.signal) account;
                inherit (cfg.signal) allowFrom;
              }
              // lib.optionalAttrs (cfg.signal.allowFrom != [ ]) {
                defaultTo = builtins.head cfg.signal.allowFrom;
              };
          };
        }
      )
      cfg.extraConfig
  );
in
{
  config = mkIf cfg.enable {

    environment = {
      # CLI available system-wide
      systemPackages = [ openclaw ];

      # Shared client config for CLI users (restricted — contains gateway token)
      etc."openclaw-client.json" = {
        text = builtins.toJSON {
          gateway = {
            inherit (cfg) port;
            inherit (cfg) bind;
            auth = {
              mode = "token";
              token = cfg.gatewayToken;
            };
          };
          models = {
            providers = {
              ${modelProvider.name} = {
                inherit (modelProvider) baseUrl;
                models = [
                  {
                    id = modelProvider.modelId;
                    name = modelProvider.modelName;
                  }
                ];
              } // lib.optionalAttrs (modelProvider.apiKey != null) {
                inherit (modelProvider) apiKey;
              } // lib.optionalAttrs (modelProvider.api != null) {
                inherit (modelProvider) api;
              };
            };
          };
        };
        mode = "0640";
        group = "users";
      };

      variables = {
        OPENCLAW_CONFIG_PATH = "/etc/openclaw-client.json";
      };
    };

    # Gateway service
    systemd.services.openclaw-gateway = {
      description = "OpenClaw Gateway";
      after = [
        "network-online.target"
      ] ++ lib.optional (!useClaudeProxy) "ollama.service";
      wants = [
        "network-online.target"
      ] ++ lib.optional (!useClaudeProxy) "ollama.service";
      wantedBy = [ "multi-user.target" ];

      path = [ pkgs.lsof pkgs.psmisc ];

      environment = {
        NODE_ENV = "production";
        OPENCLAW_STATE_DIR = "%S/openclaw";
        OPENCLAW_CONFIG_PATH = "%S/openclaw/openclaw.json";
        OPENCLAW_NIX_MODE = "1";
        HOME = "%S/openclaw";
      };

      serviceConfig = {
        ExecStartPre = pkgs.writeShellScript "openclaw-config" ''
          cat > ${stateDir}/openclaw.json <<'CONFIGEOF'
          ${openclawConfig}
          CONFIGEOF
        '';

        ExecStart = ''
          ${openclaw}/bin/openclaw gateway run \
            --bind ${cfg.bind} \
            --port ${toString cfg.port} \
            --token ${cfg.gatewayToken} \
            --allow-unconfigured
        '';

        Restart = "always";
        RestartSec = 5;
        TimeoutStopSec = 30;
        TimeoutStartSec = 60;
        DynamicUser = true;
        StateDirectory = "openclaw";
        StateDirectoryMode = "0750";

        # Hardening
        NoNewPrivileges = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        PrivateTmp = true;
        PrivateDevices = true;
        ProtectKernelTunables = true;
        ProtectKernelModules = true;
        ProtectControlGroups = true;
        RestrictNamespaces = true;
        RestrictAddressFamilies = [ "AF_INET" "AF_INET6" "AF_UNIX" ];
        SystemCallArchitectures = "native";
        CapabilityBoundingSet = "";
      };
    };

    # Persistence handled by StateDirectory + /var/lib/private (already persisted by AI module)
  };
}
