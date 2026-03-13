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
          description = "Enable AI tools (auto-enables system-level my.ai.enable)";
        };
      };
    };
  };
}
