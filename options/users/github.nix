{ lib, ... }:

{
  options.github = lib.mkOption {
    description = "GitHub configuration for this user";
    default = { };
    type = lib.types.submodule {
      options = {
        username = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = "GitHub username for this user";
          example = "i-am-logger";
        };

        repositories = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          description = "Repository names to create GitHub Actions runners for (requires my.infra.github-runner.enable)";
          example = [ "dotfiles" "mynixos" "website" ];
        };
      };
    };
  };
}
