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
    let
      categories = [
        { singular = "browser"; plural = "browsers"; }
        { singular = "terminal"; plural = "terminals"; }
        { singular = "editor"; plural = "editors"; }
        { singular = "launcher"; plural = "launchers"; }
        { singular = "fileManager"; plural = "fileManagers"; }
        { singular = "shell"; plural = "shells"; }
        { singular = "multiplexer"; plural = "multiplexers"; }
      ];

      mkConflictAssertion = userName: env: { singular, plural }: {
        assertion = !((env.${singular} or null) != null && (env.${plural} or null) != null);
        message = "User ${userName}: Cannot set both environment.${singular} and environment.${plural}";
      };
    in
    lib.flatten (lib.mapAttrsToList
      (userName: userCfg:
        let
          env = userCfg.environment or { };
        in
        map (mkConflictAssertion userName env) categories
      )
      (lib.attrByPath [ "my" "users" ] { } config));
}
