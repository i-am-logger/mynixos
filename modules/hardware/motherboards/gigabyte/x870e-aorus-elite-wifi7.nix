{ config, lib, ... }:

with lib;

{
  imports = [
    ./x870e-aorus-elite-wifi7
  ];

  config = mkIf config.my.hardware.motherboards.gigabyte.x870e-aorus-elite-wifi7.enable {
    # The actual hardware configuration is in the directory module
  };
}
