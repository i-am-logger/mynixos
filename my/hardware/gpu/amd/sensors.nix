# amdgpu's hwmon channels on a discrete Radeon.
#
# Its own file because my.hardware is one submodule option: a part defined
# inside default.nix's `mkIf` would make reading my.hardware depend on itself.
# The mkIf here sits on the part's value instead (my/hardware/sensors).
{ config, lib, ... }:

{
  my.hardware.sensors.parts.graphics = lib.mkIf (config.my.hardware.gpu == "amd") {
    kind = "graphics";
    hwmon = "amdgpu";
    sensors = [
      { channel = { kind = "temperature"; index = 1; }; label = "edge"; }
      { channel = { kind = "temperature"; index = 2; }; label = "junction"; }
      { channel = { kind = "temperature"; index = 3; }; label = "mem"; }
      { channel = { kind = "power"; index = 1; }; label = "PPT"; }
    ];
  };
}
