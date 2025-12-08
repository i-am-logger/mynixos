{ lib }:

{
  # Create a structured app option with enable, persisted, and persistedDirectories
  mkAppOption =
    {
      name,
      default ? false,
      description,
      persistedDirectories ? [ ],
      extraOptions ? { }, # Additional app-specific options
    }:
    lib.mkOption {
      type = lib.types.submodule {
        options = {
          enable = lib.mkOption {
            type = lib.types.bool;
            inherit default;
            description = "${description}${if default then " (opinionated default: enabled)" else ""}";
          };
          persisted = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "Persist app data directories";
          };
          persistedDirectories = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = persistedDirectories;
            description = "Directories to persist for this app (relative to user home)";
          };
        } // extraOptions; # Merge in extra app-specific options
      };
      default = {
        enable = default;
        persisted = true;
        inherit persistedDirectories;
      };
      description = "${description}${if default then " (opinionated default: enabled)" else ""}";
    };

  # Create an app option with opinionated default (enabled by default)
  # Users can override with my.users.<name>.apps.<category>.<app>.enable = false
  mkAppEnableOption = description: lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = "${description} (opinionated default: enabled)";
  };

  # Create an app category submodule with multiple apps
  mkAppCategory = { apps }: lib.types.submodule { options = apps; };
}
