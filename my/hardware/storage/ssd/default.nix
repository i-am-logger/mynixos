{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.my.hardware.storage.ssd;
in
{
  options.my.hardware.storage.ssd = {
    enable = mkEnableOption "SSD/NVMe optimizations (TRIM service)";
  };

  config = mkIf cfg.enable {
    # Enable periodic TRIM for SSD/NVMe longevity and performance
    # TRIM discards unused blocks on SSDs to maintain performance and extend lifespan
    services.fstrim = {
      enable = mkDefault true;
      interval = mkDefault "weekly"; # Run weekly by default
    };
  };
}
