# The channels corsair-psu reports for this unit (read on ads-dev1), and its
# nameplate watts: a product fact the driver can't report.
#
# Its own file because my.hardware is one submodule option: a part defined
# inside default.nix's `mkIf` would make reading my.hardware depend on itself.
# The mkIf here sits on the part's value instead (my/hardware/sensors).
{ config, lib, ... }:

{
  my.hardware.sensors.parts.power-supply = lib.mkIf config.my.hardware.powerSupplies.corsair.hx1200i.enable {
    kind = "power-supply";
    hwmon = "corsairpsu";
    limits.ratedPowerWatts = 1200;
    sensors =
      let ch = kind: index: label: { channel = { inherit kind index; }; inherit label; };
      in [
        (ch "temperature" 1 "vrm temp")
        (ch "temperature" 2 "case temp")
        (ch "power" 1 "power total")
        (ch "power" 2 "power +12v")
        (ch "power" 3 "power +5v")
        (ch "power" 4 "power +3.3v")
        (ch "voltage" 0 "v_in")
        (ch "voltage" 1 "v_out +12v")
        (ch "voltage" 2 "v_out +5v")
        (ch "voltage" 3 "v_out +3.3v")
        (ch "current" 2 "curr +12v")
        (ch "current" 3 "curr +5v")
        (ch "current" 4 "curr +3.3v")
        (ch "fan" 1 "psu fan")
      ];
  };
}
