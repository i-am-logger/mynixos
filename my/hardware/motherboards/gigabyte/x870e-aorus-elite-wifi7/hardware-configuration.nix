# Hardware configuration for Gigabyte X870E AORUS Elite WiFi7
# Most hardware configuration is now handled by component modules
{
  config,
  lib,
  pkgs,
  modulesPath,
  ...
}:

{
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
  ];

  # Boot module packages (empty for this motherboard)
  boot.extraModulePackages = [ ];
}
