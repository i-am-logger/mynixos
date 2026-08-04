# Persistence for the secrets directory, on Linux.
#
# `my.system.persistence.features` is impermanence's collection point and exists
# only on Linux. macOS has no impermanence, so ~/.secrets simply stays where it
# is and there is nothing to declare.
#
# Gated on the same `my.secrets.enable` as ./default.nix, which creates the
# directory: a host that does not use sops has no ~/.secrets, and persisting a
# path nothing writes is noise in the persist set.
#
# Imported only by platforms/linux.nix.
{ config, lib, ... }:

{
  config = lib.mkIf config.my.secrets.enable {
    my.system.persistence.features.userDirectories = [ ".secrets" ];
  };
}
