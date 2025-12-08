# mynixos Opinionated Defaults: AI Apps
#
# This file defines which apps are enabled when ai.enable = true
# Users can override by setting apps.{app}.enable = false

{ lib, ... }:

{
  # Inject opinionated defaults into user submodule
  options.my.users = lib.mkOption {
    type = lib.types.attrsOf (lib.types.submodule ({ config, ... }: {
      config = lib.mkIf (config.ai.enable or false) {
        apps.ai.tools = {
          # AI tools
          opencode.enable = lib.mkDefault true;
        };
      };
    }));
  };
}
