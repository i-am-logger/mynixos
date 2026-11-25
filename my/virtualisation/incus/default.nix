# my.virtualisation.incus -- system containers (LXC) and VMs (QEMU) under one
# daemon, with an optional web UI.
#
# Initialised by preseed, which nixpkgs re-applies on every change and which
# never DELETES anything: a pool, a NAT bridge and a default profile wiring the
# two together, so `incus launch images:debian/13 c1` works on first boot.
# Instances themselves are not declared here (preseed has no instances).
{ config, lib, ... }:

let
  cfg = config.my.virtualisation.incus;
  poolSource = "/var/lib/incus-pool/default";
in
{
  config = lib.mkIf cfg.enable {
    virtualisation.incus = {
      enable = true;
      ui.enable = cfg.ui.enable;

      preseed = {
        config = lib.optionalAttrs cfg.ui.enable {
          "core.https_address" = cfg.ui.listen;
        };

        storage_pools = [{
          name = "default";
          driver = cfg.storage;
          # Outside /var/lib/incus/storage-pools, which is where Incus MOUNTS
          # the pool. btrfs wants an existing subvolume here (a plain directory
          # is refused), which the tmpfiles `v` rule below creates; dir takes
          # any directory, which is what `v` falls back to off btrfs.
          config.source = poolSource;
        }];

        networks = [{
          name = "incusbr0";
          type = "bridge";
          config = {
            "ipv4.address" = "auto";
            "ipv4.nat" = "true";
            "ipv6.address" = "auto";
            "ipv6.nat" = "true";
          };
        }];

        profiles = [{
          name = "default";
          devices = {
            root = { type = "disk"; path = "/"; pool = "default"; };
            eth0 = { type = "nic"; name = "eth0"; network = "incusbr0"; };
          };
        }];
      };
    };

    # nixpkgs refuses Incus on an iptables firewall ("Incus on NixOS is
    # unsupported using iptables"). mkDefault, so a host can still say
    # otherwise -- and then gets nixpkgs' assertion, which is the honest result.
    networking.nftables.enable = lib.mkDefault true;

    # The bridge's DHCP and DNS (Incus' own dnsmasq) must be reachable from the
    # instances behind it.
    networking.firewall.trustedInterfaces = [ "incusbr0" ];

    users.users = lib.genAttrs cfg.users (_: { extraGroups = [ "incus-admin" ]; });

    systemd.tmpfiles.rules = [
      "d /var/lib/incus-pool 0711 root root -"
      "v ${poolSource} 0711 root root -"
    ];

    # Images, instances, storage pools and the daemon's database.
    my.system.persistence.features.systemDirectories = [ "/var/lib/incus" "/var/lib/incus-pool" ];

    assertions = [{
      # RKE2's rpfilter exemption for Cilium's interfaces is written with
      # ip46tables (my/infra/rke2/default.nix), which does nothing on an
      # nftables firewall: Cilium traffic would be silently dropped by
      # reverse-path filtering. Refused until RKE2 has an nftables branch.
      assertion = !config.my.infra.rke2.enable;
      message = ''
        my.virtualisation.incus and my.infra.rke2 cannot both be enabled yet.
        Incus needs the nftables firewall, and RKE2's reverse-path exemption
        for Cilium is iptables-only, so the cluster's traffic would be dropped.
      '';
    }];
  };
}
