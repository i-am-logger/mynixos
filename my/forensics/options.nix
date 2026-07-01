{ lib, ... }:

{
  forensics = lib.mkOption {
    description = ''
      Crash/fault diagnostics. Captures every diagnostic artifact - GPU faults,
      kernel panics, userspace coredumps - and retains the ambient system log,
      so a fault is diagnosable to root cause without sudo (artifacts land under
      /var/log/forensics, wheel-readable). Cross-cutting intent only: each
      subsystem owner (systemd, kernel/boot, the active GPU driver) reads this
      and configures itself. On by default; opt a host out if undesired.
    '';
    default = { };
    type = lib.types.submodule {
      options = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Diagnostics foundation: persistent, retained system log + the /var/log/forensics capture root.";
        };

        level = lib.mkOption {
          type = lib.types.enum [ "emerg" "alert" "crit" "err" "warning" "notice" "info" "debug" ];
          default = "debug";
          description = ''
            Floor severity kept in the ambient system log; drives the kernel
            console loglevel and journald MaxLevelStore. "debug" keeps everything
            (the forensics default); raise toward "crit" to keep only severe
            events (and a quieter boot). The artifact captures below fire on
            their event regardless of level.
          '';
        };

        gpu = {
          enable = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "Capture GPU faults (devcoredump + browser GPU-log) via the active GPU driver, into /var/log/forensics/gpu.";
          };
        };

        kernel = {
          enable = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "Capture kernel panics/oopses across reboot via pstore-ramoops, into /var/log/forensics/kernel.";
          };
        };

        userspace = {
          enable = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "Retain userspace process coredumps via systemd-coredump (read with coredumpctl).";
          };
        };
      };
    };
  };
}
