{ lib }:

{
  # Float type constrained to a range [min, max]
  floatBetween = min: max:
    lib.types.addCheck lib.types.float (x: x >= min && x <= max)
    // { description = "float between ${toString min} and ${toString max}"; };

  # Create a structured app option with enable, persisted, and persistedDirectories
  mkAppOption =
    { name
    , default ? false
    , description
    , persistedDirectories ? [ ]
    , persistedFiles ? [ ]
    , extraOptions ? { }
    , # Additional app-specific options
    }:
    let
      desc = "${name}: ${description}";
    in
    lib.mkOption {
      type = lib.types.submodule {
        options = {
          enable = lib.mkOption {
            type = lib.types.bool;
            inherit default;
            description = "${desc}${if default then " (opinionated default: enabled)" else ""}";
          };
          persisted = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "Persist app data directories and files";
          };
          persistedDirectories = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = persistedDirectories;
            description = "Directories to persist for this app (relative to user home)";
          };
          persistedFiles = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = persistedFiles;
            description = "Files to persist for this app (relative to user home)";
          };
        } // extraOptions; # Merge in extra app-specific options
      };
      default = {
        enable = default;
        persisted = true;
        inherit persistedDirectories;
        inherit persistedFiles;
      };
      description = "${desc}${if default then " (opinionated default: enabled)" else ""}";
    };
}
