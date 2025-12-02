{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.hardware.motherboard;

  # Helper to create motherboard option and import
  mkMotherboard = vendor: model: path: {
    options.hardware.motherboard.${vendor}.${model} = {
      enable = mkEnableOption "${vendor} ${model} motherboard";
    };

    config = mkIf cfg.${vendor}.${model}.enable {
      imports = [ path ];
    };
  };

in
{
  imports = [
    # Gigabyte motherboards
    (mkMotherboard "gigabyte" "x870e-aorus-elite-wifi7"
      ./gigabyte/x870e-aorus-elite-wifi7)

    # Lenovo motherboards
    (mkMotherboard "lenovo" "legion-16irx8h"
      ./lenovo/legion-16irx8h)
  ];
}
