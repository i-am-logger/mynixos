{ activeUsers, config, lib, pkgs, ... }:

with lib;

let
  cfg = config.my.ai.claudeProxy;

  claude-proxy = pkgs.rustPlatform.buildRustPackage {
    pname = "claude-proxy";
    version = "0.2.0";

    src = pkgs.fetchCrate {
      pname = "claude-proxy";
      version = "0.2.0";
      hash = "sha256-c+7zdnpitwCdCfB7WtpZDhiZPBAVJEjbTg/QEcs+1RM=";
    };

    cargoHash = "sha256-qen/pfjKbJrzRUJXKXi9iUkNrITdqo8Czz4SWrloe9Y=";

    meta = {
      description = "OpenAI-compatible API proxy for Claude Code CLI";
      mainProgram = "claude-proxy";
    };
  };
in
{
  config = mkIf cfg.enable {
    # Per-user systemd service via home-manager (needs ~/.claude credentials)
    home-manager.users = mapAttrs
      (_name: userCfg:
        mkIf (userCfg.ai.enable or false) {
          home.packages = [ claude-proxy ];

          systemd.user.services.claude-proxy = {
            Unit = {
              Description = "Claude Code OpenAI-compatible proxy";
              After = [ "network-online.target" ];
              Wants = [ "network-online.target" ];
            };

            Service = {
              ExecStart = "${claude-proxy}/bin/claude-proxy --api-key ${cfg.apiKey} --port ${toString cfg.port} --model ${cfg.model}";
              Restart = "on-failure";
              RestartSec = 5;
            };

            Install = {
              WantedBy = [ "default.target" ];
            };
          };
        })
      (activeUsers config.my.users);
  };
}
