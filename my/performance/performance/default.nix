{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.my.performance;
in
{
  config = mkIf cfg.enable {
    # Kernel and memory optimizations
    boot.kernel.sysctl = {
      # Network optimizations - BBR congestion control
      "net.core.default_qdisc" = mkDefault "fq";
      "net.ipv4.tcp_congestion_control" = mkDefault "bbr";

      # Filesystem inotify limits (for IDEs, file watchers, etc.)
      # Use mkForce because nixpkgs also sets these
      "fs.inotify.max_user_watches" = mkForce 524288;
      "fs.inotify.max_queued_events" = mkForce 524288;

      # I/O and memory optimizations
      "vm.swappiness" = mkDefault 1;
      "vm.vfs_cache_pressure" = mkDefault 50;
      "vm.dirty_background_ratio" = mkDefault 3;
      "vm.dirty_ratio" = mkDefault 8;
      "vm.transparent_hugepage" = mkDefault "madvise";
      # Use mkForce because nixpkgs sets this to 1048576
      "vm.max_map_count" = mkForce 262144;
    };

    # zram compressed swap (15% of RAM by default)
    zramSwap = {
      enable = mkDefault true;
      memoryPercent = mkDefault cfg.zramPercent;
    };

    # vmtouch RAM caching service - keeps system closure in RAM for fast access
    systemd.services.nix-system-ram = mkIf cfg.vmtouchCache {
      description = "Load current system closure into RAM";
      wantedBy = [ "multi-user.target" ];
      after = [ "local-fs.target" ];

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = pkgs.writeShellScript "cache-system" ''
          # Cache current system
          ${pkgs.vmtouch}/bin/vmtouch -dl $(readlink -f /run/current-system)

          # Also cache current user profile (if exists)
          for user in ${concatStringsSep " " (attrNames config.my.users)}; do
            if [ -d /nix/var/nix/profiles/per-user/$user ]; then
              ${pkgs.vmtouch}/bin/vmtouch -dl /nix/var/nix/profiles/per-user/$user/profile
            fi
          done

          # Cache frequently used applications
          ${pkgs.vmtouch}/bin/vmtouch -dl /nix/store/*-firefox-* 2>/dev/null || true

          # Report status
          echo "Current system closure size:"
          ${pkgs.nix}/bin/nix path-info -Sh /run/current-system
        '';
        ExecStop = pkgs.writeShellScript "uncache-system" ''
          ${pkgs.vmtouch}/bin/vmtouch -e $(readlink -f /run/current-system)
          for user in ${concatStringsSep " " (attrNames config.my.users)}; do
            if [ -d /nix/var/nix/profiles/per-user/$user ]; then
              ${pkgs.vmtouch}/bin/vmtouch -e /nix/var/nix/profiles/per-user/$user/profile
            fi
          done
          ${pkgs.vmtouch}/bin/vmtouch -e /nix/store/*-firefox-* 2>/dev/null || true
        '';

        MemoryMax = "16G";
        Restart = "no";
        TimeoutStartSec = "5m";
      };
    };

    # Disable auto-generated timer (service runs once at boot)
    systemd.timers.nix-system-ram = mkIf cfg.vmtouchCache {
      enable = false;
      timerConfig = { };
    };
  };
}
