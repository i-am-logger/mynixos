# Corsair HX1200i Series 2025 (ATX 3.1, CP-9020307, USB 1b1c:1c27).
#
# Sensors only. The in-kernel corsair-psu hwmon driver (6.17+, commit
# 6082bfe47795) reports input voltage, the +12V/+5V/+3.3V rails' voltage,
# current and power, total power, fan rpm and the VRM/case temperatures;
# lm_sensors' `sensors` shows them.
#
# Deliberately NOT done:
# - Fan control. The driver exposes pwm1/pwm1_enable read-only, and the
#   firmware's automatic curve (pwm1_enable = 2) is what the unit ships with.
# - +12V OCP (single/multi rail). Only `liquidctl initialize --direct-access`
#   can set it, talking hidraw beside the bound kernel driver -- which keeps
#   one command buffer and no lock against other hidraw users, so the two can
#   garble each other's replies. Add it when a rail mode actually has to change.
#
# The front LED alternating green/amber is the unit talking to the host over
# USB (Corsair staff, HX1500i/HX850i threads): every sensor read is a HID
# transaction. Steady red is the fault indication; there is no LED control.
{ config, lib, pkgs, ... }:

let
  cfg = config.my.hardware.powerSupplies.corsair.hx1200i;
in
{
  imports = [ ./sensors.nix ];

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = lib.versionAtLeast config.boot.kernelPackages.kernel.version "6.17";
        message = "my.hardware.powerSupplies.corsair.hx1200i: the corsair-psu driver learned this unit (1b1c:1c27) in Linux 6.17; this kernel is ${config.boot.kernelPackages.kernel.version}, so no sensors would appear.";
      }
    ];

    # It autoloads on the HID match; stated so the dependency is explicit.
    boot.kernelModules = [ "corsair-psu" ];

    environment.systemPackages = [ pkgs.lm_sensors ];
  };
}
