{ lib }:

let
  # Relative path type: non-empty string that doesn't start with / or contain ..
  relativePath = lib.types.addCheck lib.types.nonEmptyStr
    (s: !(lib.hasPrefix "/" s) && !(lib.hasPrefix ".." s) && !(lib.hasInfix "/../" s) && !(lib.hasSuffix "/.." s))
  // { description = "relative path (no leading / or ..)"; };
in
{
  # Float type constrained to a range [min, max]
  floatBetween = min: max:
    lib.types.addCheck lib.types.float (x: x >= min && x <= max)
    // { description = "float between ${toString min} and ${toString max} (inclusive)"; };

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
            type = lib.types.listOf relativePath;
            default = persistedDirectories;
            description = "Directories to persist for this app (relative to user home, no absolute paths or ..)";
          };
          persistedFiles = lib.mkOption {
            type = lib.types.listOf relativePath;
            default = persistedFiles;
            description = "Files to persist for this app (relative to user home, no absolute paths or ..)";
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
