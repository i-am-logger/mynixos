# my.virtualisation.incus — system containers (LXC) and VMs (QEMU) under one
# daemon, CLI/REST and optional web UI. It spans both kinds, so it sits beside
# `containers` and `vms` rather than inside either. Linux only. Type-only;
# ../options.nix owns `virtualisation`.
{ lib, ... }:

{
  virtualisation = lib.mkOption {
    type = lib.types.submodule {
      options.incus = lib.mkOption {
        description = "Incus: system containers and VMs";
        default = { };
        type = lib.types.submodule {
          options = {
            enable = lib.mkEnableOption ''
              Incus (system containers and VMs). Switches the firewall to
              nftables, which nixpkgs requires for Incus
            '';

            users = lib.mkOption {
              type = lib.types.listOf lib.types.str;
              default = [ ];
              example = [ "alice" ];
              description = ''
                Accounts added to `incus-admin`, which drives the daemon without
                a password. That is ROOT-EQUIVALENT (a member can attach any host
                path to an instance), so the list is explicit, never every user.
              '';
            };

            storage = lib.mkOption {
              type = lib.types.enum [ "dir" "btrfs" ];
              default = "dir";
              description = ''
                Driver of the `default` storage pool under /var/lib/incus.
                "btrfs" gives instant snapshots and copies when /var/lib/incus
                is on btrfs; "dir" works anywhere.
              '';
            };

            ui = {
              enable = lib.mkEnableOption "the Incus web UI";

              listen = lib.mkOption {
                type = lib.types.str;
                default = "127.0.0.1:8443";
                description = ''
                  Address the API and UI listen on (core.https_address).
                  Localhost by default; reach it over an SSH tunnel or
                  `tailscale serve` rather than opening it to the network.
                '';
              };
            };
          };
        };
      };
    };
  };
}
