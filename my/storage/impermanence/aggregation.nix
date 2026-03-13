{ config, lib, ... }:

with lib;

let
  # Recursively collect leaf app configs from the nested apps structure.
  # Leaf nodes are attrsets that have an "enable" attribute.
  # Non-leaf nodes are attrsets of subcategories to recurse into.
  collectApps = prefix: attrs:
    flatten (mapAttrsToList
      (name: value:
        if isAttrs value && value ? enable then
        # Leaf app node (has enable attribute)
          [{ name = "${prefix}.${name}"; appConfig = value; }]
        else if isAttrs value then
        # Subcategory - recurse deeper
          collectApps "${prefix}.${name}" value
        else
          [ ]
      )
      attrs);

  # Aggregate persistence directories for a single user
  aggregatePersistenceForUser = _userName: userConfig:
    let
      # Recursively collect all leaf apps from the nested structure
      allApps = collectApps "" userConfig.apps;

      # Filter to only apps that are enabled and persisted
      enabledPersistedApps = filter
        (app:
          (app.appConfig.enable or false) &&
          (app.appConfig.persisted or false)
        )
        allApps;

      # Extract all directories from enabled persisted apps
      directories = flatten (map
        (app: app.appConfig.persistedDirectories or [ ])
        enabledPersistedApps);

      # Extract all files from enabled persisted apps
      files = flatten (map
        (app: app.appConfig.persistedFiles or [ ])
        enabledPersistedApps);

      # Get list of app names
      appNames = map (app: app.name) enabledPersistedApps;
    in
    {
      directories = unique directories;
      files = unique files;
      apps = appNames;
    };

  # Aggregate for all users
  userPersistence = mapAttrs aggregatePersistenceForUser config.my.users;
in
{
  # Populate the read-only aggregated persistence data
  config.my.system.persistence.aggregated = userPersistence;
}
