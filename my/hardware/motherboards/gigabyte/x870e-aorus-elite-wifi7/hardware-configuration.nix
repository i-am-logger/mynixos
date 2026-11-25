# Hardware configuration for Gigabyte X870E AORUS Elite WiFi7
# Most hardware configuration is now handled by component modules
{ config
, lib
, modulesPath
, ...
}:

let
  cfg = config.my.hardware.motherboards.gigabyte.x870e-aorus-elite-wifi7;
in
{
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
  ];

  # Everything below is gated on the board being the one in the machine. A
  # module's `imports` cannot be conditional, so this file is evaluated on every
  # host that has the motherboard set in scope — ungated, its kernel params and
  # firmware would land on hardware that has neither this chipset nor this
  # board's HDMI wiring.
  config = lib.mkIf cfg.enable {
    # Boot module packages (empty for this motherboard)
    boot.extraModulePackages = [ ];

    # The Elgato 4K X's HDMI workaround (forced EDID, HDMI audio pins) used to
    # live here; it is the card's, not the board's:
    # my.hardware.peripherals.elgato.game-capture-4k-x.passthrough.
  };
}
