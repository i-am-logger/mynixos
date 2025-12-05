{ config, lib, ... }:

with lib;

let
  cfg = config.my.hardware.laptops.lenovo.legion-16irx8h;
in
{
  imports = mkIf cfg.enable [
    ./legion-16irx8h
  ];
}
