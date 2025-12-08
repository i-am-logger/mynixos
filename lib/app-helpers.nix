{ lib }:

{
  # Check if an app should be enabled
  # 
  # Usage:
  #   appHelpers.shouldEnable userCfg "prompts" "starship"
  #
  # Structure: apps.{feature}.{category}.{app}
  # The function tries to find the app in any feature namespace
  shouldEnable = userCfg: category: app:
    let
      # Try to find the app in each feature namespace
      terminalApp = userCfg.apps.terminal.${category}.${app} or null;
      graphicalApp = userCfg.apps.graphical.${category}.${app} or null;
      devApp = userCfg.apps.dev.${category}.${app} or null;
      mediaApp = userCfg.apps.media.${category}.${app} or null;
      artApp = userCfg.apps.art.${category}.${app} or null;
      communicationApp = userCfg.apps.communication.${category}.${app} or null;
      securityApp = userCfg.apps.security.${category}.${app} or null;
      financeApp = userCfg.apps.finance.${category}.${app} or null;
      aiApp = userCfg.apps.ai.${category}.${app} or null;
      
      # Find the first non-null app
      appValue = 
        if terminalApp != null then terminalApp
        else if graphicalApp != null then graphicalApp
        else if devApp != null then devApp
        else if mediaApp != null then mediaApp
        else if artApp != null then artApp
        else if communicationApp != null then communicationApp
        else if securityApp != null then securityApp
        else if financeApp != null then financeApp
        else if aiApp != null then aiApp
        else { enable = false; };
      
      # Check explicit app enable (all apps have .enable)
      appEnabled = appValue.enable or false;
    in
    appEnabled;
}
