# Composite is every NVMe drive's own summary temperature; further sensors
# vary by model.
#
# Its own file because my.hardware is one submodule option: a part defined
# inside default.nix's `mkIf` would make reading my.hardware depend on itself.
# The mkIf here sits on the part's value instead (my/hardware/sensors).
{ config, lib, ... }:

{
  my.hardware.sensors.parts.storage = lib.mkIf config.my.hardware.storage.nvme.enable {
    kind = "storage";
    hwmon = "nvme";
    sensors = [{ channel = { kind = "temperature"; index = 1; }; label = "Composite"; }];
  };
}
