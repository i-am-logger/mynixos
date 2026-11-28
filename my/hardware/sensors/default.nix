# Renders my.hardware.sensors.parts to /etc/mynixos/sensors.json (schema 1):
#   { "schema": 1, "parts": [ { "kind", "hwmon", "sensors": [ { "quantity", "channel", "label" } ], "limits" } ] }
# A part with no sensors is left out; limits carry only what is set.
{ config, lib, pkgs, ... }:

let
  cfg = config.my.hardware.sensors;

  prefix = {
    temperature = "temp";
    power = "power";
    voltage = "in";
    fan = "fan";
    current = "curr";
    energy = "energy";
  };
  channelName = c: "${prefix.${c.kind}}${toString c.index}";

  render = p: {
    inherit (p) kind hwmon;
    sensors = map
      (s: {
        quantity = s.channel.kind;
        channel = channelName s.channel;
        inherit (s) label;
      })
      p.sensors;
    limits = lib.filterAttrs (_: v: v != null) p.limits;
  };

  # Voltages count from 0 (in0); every other hwmon channel kind from 1.
  badChannels = lib.concatLists (lib.mapAttrsToList
    (name: p: map (s: "${name}: ${channelName s.channel}")
      (lib.filter (s: s.channel.kind != "voltage" && s.channel.index == 0) p.sensors))
    cfg.parts);
in
{
  config = {
    assertions = [{
      assertion = badChannels == [ ];
      message = "my.hardware.sensors.parts: hwmon numbers these channels from 1, not 0: ${lib.concatStringsSep ", " badChannels}";
    }];

    # The mkIf sits on the part, not on my.hardware (one submodule option).
    my.hardware.sensors.parts.memory = lib.mkIf (cfg.memoryTemperatureSensor != "none") {
      kind = "memory";
      hwmon = cfg.memoryTemperatureSensor;
      sensors = [{ channel = { kind = "temperature"; index = 1; }; }];
    };

    environment.etc."mynixos/sensors.json".source = (pkgs.formats.json { }).generate "sensors.json" {
      schema = 1;
      parts = map render (lib.filter (p: p.sensors != [ ]) (lib.attrValues cfg.parts));
    };
  };
}
