{ lib, ... }:

{
  options.ai = lib.mkOption {
    description = "AI tools configuration";
    default = { };
    type = lib.types.submodule {
      options = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Enable AI tools (MCP servers, requires system-level my.features.ai.enable)";
        };
      };
    };
  };
}
