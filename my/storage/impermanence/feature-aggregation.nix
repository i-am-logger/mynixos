{ config, lib, ... }:

with lib;

# Feature modules will add to these lists via mkMerge
# This module provides the aggregation structure
{
  # Features will populate config.my.system.persistence.features directly
  # using mkMerge in their respective modules

  # Example of what a feature module will do:
  # config.my.system.persistence.features.systemDirectories =
  #   mkIf config.my.graphical.enable [ "/var/lib/gnome" ... ];
}
