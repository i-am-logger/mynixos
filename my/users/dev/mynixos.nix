# mynixos Opinionated Defaults: Dev Apps
#
# This file defines which apps are enabled when dev.enable = true
# Users can override by setting apps.{app}.enable = false

{ lib, ... }:

{
  # Inject opinionated defaults into user submodule
  options.my.users = lib.mkOption {
    type = lib.types.attrsOf (
      lib.types.submodule (
        { config, ... }:
        {
          config = lib.mkIf (config.dev.enable or false) {
            apps.dev.tools = {
              # Development tools
              direnv.enable = lib.mkDefault true;
              devenv.enable = lib.mkDefault true;
              jq.enable = lib.mkDefault true;
            };
          };
        }
      )
    );
  };
}
