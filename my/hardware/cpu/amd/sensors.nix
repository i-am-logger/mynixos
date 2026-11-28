# Tctl is every Zen part's control temperature; the per-CCD channels
# (Tccd1..) depend on the model, so they belong to a model profile.
#
# Its own file because my.hardware is one submodule option: a part defined
# inside default.nix's `mkIf` would make reading my.hardware depend on itself.
# The mkIf here sits on the part's value instead (my/hardware/sensors).
{ config, lib, ... }:

{
  my.hardware.sensors.parts.processor = lib.mkIf (config.my.hardware.cpu == "amd") {
    kind = "processor";
    hwmon = "k10temp";
    sensors = [{ channel = { kind = "temperature"; index = 1; }; label = "Tctl"; }];
  };
}
