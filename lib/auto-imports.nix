{ lib }:

let
  # Recursively import all .nix files in a directory tree
  # Strategy: Import standalone .nix files, OR import directories with default.nix
  # Used for implementation modules (my/) only
  autoImport =
    dir:
    let
      # Get all entries in directory
      entries = builtins.readDir dir;

      # Process each entry
      processEntry =
        name: type:
        let
          path = dir + "/${name}";
        in
        if type == "directory" then
          # For directories, check if they have default.nix
          let
            defaultNix = path + "/default.nix";
          in
          if builtins.pathExists defaultNix then
            # Directory with default.nix - import the directory itself
            [ path ]
          else
            # No default.nix - recurse into directory
            autoImport path
        else if type == "regular" && lib.hasSuffix ".nix" name then
          # Regular .nix file (but not default.nix at this level)
          if
            name != "default.nix"
            && !(lib.hasPrefix "_" name)
            && !(lib.hasPrefix "test-" name)
          then
            [ path ]
          else
            [ ]
        else
          # Skip other file types
          [ ];

      # Flatten all processed entries
      allImports = lib.flatten (lib.mapAttrsToList processEntry entries);
    in
    allImports;
in
{
  inherit autoImport;
}
