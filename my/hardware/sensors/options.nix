# Hardware sensors: which hwmon devices this machine has, for a desktop that
# draws them without probing (vogix's instruments). Each hardware module adds
# its own part when it is enabled; my/hardware/sensors/default.nix renders
# them to /etc/mynixos/sensors.json.
#
# Linux only: hwmon is Linux's. Type-only, like the other hardware fragments
# (my/hardware/options.nix carries the submodule's default and description).

{ lib, ... }:

let
  inherit (lib) types mkOption;

  channel = types.submodule {
    options = {
      kind = mkOption {
        type = types.enum [ "temperature" "power" "voltage" "fan" "current" "energy" ];
        description = "The hwmon channel type: temp, power, in, fan, curr or energy.";
      };
      index = mkOption {
        type = types.ints.unsigned;
        description = "The channel number: voltages count from 0 (in0), every other kind from 1 (temp1).";
      };
    };
  };

  sensor = types.submodule {
    options = {
      channel = mkOption {
        type = channel;
        description = "The hwmon channel, rendered as hwmon's own name (temp1, in0): the stable id.";
      };
      label = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "The driver's *_label text, for display (\"Tctl\", \"power total\"); null when it has none.";
      };
    };
  };

  part = types.submodule {
    options = {
      kind = mkOption {
        type = types.enum [ "processor" "graphics" "memory" "power-supply" "storage" ];
        description = "What the part is.";
      };
      hwmon = mkOption {
        type = types.strMatching "^[a-z0-9_-]+$";
        description = "The driver's hwmon name (/sys/class/hwmon/*/name). Every device with this name is this part.";
      };
      sensors = mkOption {
        type = types.listOf sensor;
        default = [ ];
        description = "The channels the part reports. A part with none is left out of the manifest.";
      };
      limits = {
        ratedPowerWatts = mkOption {
          type = types.nullOr types.ints.positive;
          default = null;
          description = "The rated output a driver can't report (a power supply's nameplate watts).";
        };
      };
    };
  };
in
{
  hardware = mkOption {
    type = types.submodule {
      options.sensors = {
        parts = mkOption {
          type = types.attrsOf part;
          default = { };
          description = "This machine's sensor-bearing parts, by name. Hardware modules add their own.";
        };
        memoryTemperatureSensor = mkOption {
          type = types.enum [ "none" "spd5118" "jc42" ];
          default = "none";
          description = ''
            The DIMM temperature sensor the board makes readable: spd5118 (DDR5) or jc42 (DDR4). A board
            profile sets it only when its SMBus driver binds, since the kernel instantiates the sensors from
            DMI on that bus (research/SENS1.md); "none" adds no memory part.
          '';
        };
      };
    };
  };
}
