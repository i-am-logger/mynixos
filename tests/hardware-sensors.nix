# my.hardware.sensors (SENS1a): each hardware module adds its part, and
# /etc/mynixos/sensors.json carries them (schema 1). Memory appears only when
# the board names its DIMM sensor (research/SENS1.md). Refusals are paired
# with a valid config through the same accessor (docs/nix-rules.md rule 16).
{ lib
, nixpkgs
, system
, self
, inputs
}:

let
  testLib = import ./lib.nix { inherit lib nixpkgs system self inputs; };
  inherit (testLib) pkgs specialArgs baseModules baseConfig;

  evalWith = testConfig: lib.nixosSystem {
    inherit specialArgs;
    modules = baseModules ++ [ baseConfig testConfig ];
  };

  # Named clauses over the config, plus a jq program the rendered manifest
  # must satisfy (checked at build time; reading it at eval would be IFD).
  check = name: testConfig: clauses: jq:
    let
      inherit ((evalWith testConfig)) config;
      failed = builtins.attrNames (lib.filterAttrs (_: ok: !ok) (clauses config));
      manifest = config.environment.etc."mynixos/sensors.json".source;
    in
    if failed != [ ] then builtins.throw "FAIL: ${name} -- did not hold: ${lib.concatStringsSep ", " failed}"
    else
      pkgs.runCommand name { nativeBuildInputs = [ pkgs.jq ]; } ''
        jq -e ${lib.escapeShellArg jq} ${manifest} > /dev/null \
          || { echo "FAIL: ${name} -- the manifest does not satisfy: ${jq}"; cat ${manifest}; exit 1; }
        echo "PASS: ${name}"
        touch $out
      '';

  # The accessor refusals go through: valid first, so "no such option" can't
  # pass as a refusal.
  refuses = name: valid: invalid: accessor:
    let
      ok = builtins.tryEval (builtins.deepSeq (accessor (evalWith valid).config) true);
      bad = builtins.tryEval (builtins.deepSeq (accessor (evalWith invalid).config) true);
    in
    if !(ok.success && ok.value) then builtins.throw "FAIL: ${name} -- the valid config does not evaluate"
    else if bad.success then builtins.throw "FAIL: ${name} -- the invalid config was accepted"
    else pkgs.runCommand name { } "echo PASS: ${name}; touch $out";

  host = name: extra: lib.recursiveUpdate { networking.hostName = "test-${name}"; } extra;
  partsOf = config: config.my.hardware.sensors.parts;
  asserted = config: lib.all (a: a.assertion) config.assertions;
in
{
  # The PSU product profile states its nameplate watts and every channel.
  hardware-sensors-power-supply = check "hardware-sensors-power-supply"
    (host "psu" { my.hardware.powerSupplies.corsair.hx1200i.enable = true; })
    (config: {
      part = (partsOf config) ? power-supply;
      rated = (partsOf config).power-supply.limits.ratedPowerWatts or null == 1200;
    })
    ''.schema == 1 and (.parts | map(select(.kind == "power-supply" and .hwmon == "corsairpsu"
      and .limits.ratedPowerWatts == 1200
      and (.sensors | any(.channel == "power1" and .quantity == "power" and .label == "power total"))
      and (.sensors | any(.channel == "in0" and .quantity == "voltage")))) | length == 1)'';

  # The parts ads-dev1 has: AMD CPU and GPU, NVMe.
  hardware-sensors-amd-nvme = check "hardware-sensors-amd-nvme"
    (host "amd" {
      my.hardware = {
        cpu = "amd";
        gpu = "amd";
        storage.nvme.enable = true;
      };
    })
    (config: {
      processor = (partsOf config).processor.hwmon or null == "k10temp";
      graphics = (partsOf config).graphics.hwmon or null == "amdgpu";
      storage = (partsOf config).storage.hwmon or null == "nvme";
    })
    ''[.parts[] | {kind, hwmon, c: [.sensors[] | .channel + "=" + (.label // "")]}]
      | (map(select(.kind == "processor" and .hwmon == "k10temp" and (.c | index("temp1=Tctl")))) | length == 1)
      and (map(select(.kind == "graphics" and (.c | index("power1=PPT")))) | length == 1)
      and (map(select(.kind == "storage" and (.c | index("temp1=Composite")))) | length == 1)'';

  # Memory is off by default: no memory part, and the manifest has none ...
  hardware-sensors-memory-none = check "hardware-sensors-memory-none"
    (host "mem-none" { })
    (config: { noMemory = !((partsOf config) ? memory); })
    ''.schema == 1 and (.parts | map(select(.kind == "memory")) | length == 0)'';

  # ... and a board that names spd5118 gets one.
  hardware-sensors-memory-spd5118 = check "hardware-sensors-memory-spd5118"
    (host "mem-spd" { my.hardware.sensors.memoryTemperatureSensor = "spd5118"; })
    (config: { memory = (partsOf config).memory.hwmon or null == "spd5118"; })
    ''.parts | map(select(.kind == "memory" and .hwmon == "spd5118"
      and (.sensors | any(.channel == "temp1" and .quantity == "temperature")))) | length == 1'';

  # A kind outside the enum is refused (paired with a valid one).
  hardware-sensors-refuses-kind = refuses "hardware-sensors-refuses-kind"
    (host "kind-ok" { my.hardware.sensors.parts.x = { kind = "storage"; hwmon = "nvme"; }; })
    (host "kind-bad" { my.hardware.sensors.parts.x = { kind = "psu"; hwmon = "nvme"; }; })
    (config: (partsOf config).x.kind);

  # temp0 doesn't exist (hwmon counts temperatures from 1); in0 does.
  hardware-sensors-refuses-temp0 = refuses "hardware-sensors-refuses-temp0"
    (host "ch-ok" {
      my.hardware.sensors.parts.x = {
        kind = "power-supply";
        hwmon = "corsairpsu";
        sensors = [{ channel = { kind = "voltage"; index = 0; }; }];
      };
    })
    (host "ch-bad" {
      my.hardware.sensors.parts.x = {
        kind = "storage";
        hwmon = "nvme";
        sensors = [{ channel = { kind = "temperature"; index = 0; }; }];
      };
    })
    (config: if asserted config then (partsOf config).x else throw "assertion");
}
