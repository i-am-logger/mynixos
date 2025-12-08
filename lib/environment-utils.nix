{ lib }:

{
  # Normalize environment app options to a list
  # Handles singular, plural, or null
  # Returns: list of app submodules (empty if both are null)
  normalizeApps = singular: plural:
    if plural != null then
      plural
    else if singular != null then
      [ singular ]
    else
      [ ];

  # Get assertions for environment conflicts
  mkEnvironmentAssertions = config:
    lib.flatten (lib.mapAttrsToList
      (userName: userCfg:
        let
          env = userCfg.environment or { };
        in
        [
          {
            assertion = !((env.browser or null) != null && (env.browsers or null) != null);
            message = "User ${userName}: Cannot set both environment.browser and environment.browsers";
          }
          {
            assertion = !((env.terminal or null) != null && (env.terminals or null) != null);
            message = "User ${userName}: Cannot set both environment.terminal and environment.terminals";
          }
          {
            assertion = !((env.editor or null) != null && (env.editors or null) != null);
            message = "User ${userName}: Cannot set both environment.editor and environment.editors";
          }
          {
            assertion = !((env.launcher or null) != null && (env.launchers or null) != null);
            message = "User ${userName}: Cannot set both environment.launcher and environment.launchers";
          }
          {
            assertion = !((env.fileManager or null) != null && (env.fileManagers or null) != null);
            message = "User ${userName}: Cannot set both environment.fileManager and environment.fileManagers";
          }
          {
            assertion = !((env.shell or null) != null && (env.shells or null) != null);
            message = "User ${userName}: Cannot set both environment.shell and environment.shells";
          }
          {
            assertion = !((env.multiplexer or null) != null && (env.multiplexers or null) != null);
            message = "User ${userName}: Cannot set both environment.multiplexer and environment.multiplexers";
          }
        ]
      )
      (lib.attrByPath [ "my" "users" ] { } config));
}
