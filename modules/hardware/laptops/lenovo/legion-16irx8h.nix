{ config, lib, ... }:

with lib;

{
  imports = [
    ./legion-16irx8h
  ];

  config = mkIf config.my.hardware.laptops.lenovo.legion-16irx8h.enable {
    # The actual hardware configuration is in the directory module
  };
}
