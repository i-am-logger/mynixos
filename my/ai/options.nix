{ lib, ... }:

{
  ai = lib.mkOption {
    description = "AI infrastructure (Ollama service with ROCm support)";
    default = { };
    type = lib.types.submodule {
      options = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Auto-set to true when any user has ai.enable = true (managed by mynixos)";
        };

        rocmGfxVersion = lib.mkOption {
          type = lib.types.str;
          default = "11.0.2";
          description = "ROCm GFX version override for AMD GPU compatibility (opinionated default: 11.0.2 for RDNA3)";
        };
      };
    };
  };
}
