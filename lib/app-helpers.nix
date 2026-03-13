{ lib }:

{
  # Check if an app should be enabled
  #
  # Usage:
  #   appHelpers.shouldEnable userCfg "prompts" "starship"
  #
  # Structure: apps.{feature}.{category}.{app}
  # The function dynamically searches all feature namespaces
  shouldEnable = userCfg: category: app:
    let
      apps = userCfg.apps or { };
      namespaces = lib.attrNames apps;

      # Find the first namespace containing this category.app
      findApp = ns:
        let val = apps.${ns}.${category}.${app} or null;
        in val;

      matches = lib.filter (v: v != null) (map findApp namespaces);
      appValue = if matches != [ ] then lib.head matches else { enable = false; };
    in
      appValue.enable or false;
}
