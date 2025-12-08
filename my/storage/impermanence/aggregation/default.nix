{ config, lib, ... }:

with lib;

let
  # Aggregate persistence directories for a single user
  aggregatePersistenceForUser = userName: userConfig:
    let
      # Flatten all apps from all categories into a single list
      allApps = flatten (mapAttrsToList
        (category: apps:
          mapAttrsToList
            (appName: appConfig: {
              name = "${category}.${appName}";
              inherit appConfig;
            })
            apps
        )
        userConfig.apps);

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

      # Get list of app names
      appNames = map (app: app.name) enabledPersistedApps;
    in
    {
      directories = unique directories;
      apps = appNames;
    };

  # Aggregate for all users
  userPersistence = mapAttrs aggregatePersistenceForUser config.my.users;
in
{
  # Populate the read-only aggregated persistence data
  config.my.system.persistence.aggregated = userPersistence;
}
