{ config, lib, ... }:

with lib;

let
  cfg = config.my.hardware.motherboards.gigabyte.x870e-aorus-elite-wifi7;
in
{
  imports = mkIf cfg.enable [
    ./x870e-aorus-elite-wifi7
  ];
}
