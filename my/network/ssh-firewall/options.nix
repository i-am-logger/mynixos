# Options for the darwin-only pf firewall (implementation: ./default.nix).
#
# Declared here rather than in ../options.nix so the option does not exist at all
# on NixOS: setting it there fails with "The option `my.network.sshFirewall' does
# not exist" rather than silently doing nothing. `types.submodule` declarations
# for the same option merge, so this composes with the cross-platform
# `my.network` options without duplicating them.
{ lib, ... }:

{
  network = lib.mkOption {
    type = lib.types.submodule {
      options = {
        # darwin only. The NixOS equivalent is
        # networking.firewall.interfaces.tailscale0 in my/network/tailscale.
        sshFirewall = lib.mkOption {
          description = "Default-deny inbound firewall via pf (darwin)";
          default = { };
          type = lib.types.submodule {
            options = {
              enable = lib.mkEnableOption "default-deny inbound firewall via pf";

              allowTailnet = lib.mkOption {
                type = lib.types.bool;
                default = true;
                description = "Accept inbound connections from the Tailscale address space";
              };

              tailnetPorts = lib.mkOption {
                type = lib.types.nullOr (lib.types.listOf lib.types.port);
                default = [ 22 ];
                description = ''
                  TCP ports reachable from the tailnet. null means all ports,
                  trusting the control server's ACLs instead. Note restricting
                  this also blocks Tailscale's peerapi, which listens on a random
                  high port and therefore cannot be enumerated — that breaks
                  Taildrop and peer node communication.
                '';
              };

              tailscaleUdpPort = lib.mkOption {
                type = lib.types.nullOr lib.types.port;
                default = 41641;
                description = ''
                  Tailscale's UDP listen port, allowed inbound so direct
                  peer-to-peer works. null forces DERP relaying.
                '';
              };

              allowDhcp = lib.mkOption {
                type = lib.types.bool;
                default = true;
                description = "Allow DHCP replies. Off can break WiFi/Ethernet leases.";
              };

              allowMdns = lib.mkOption {
                type = lib.types.bool;
                default = true;
                description = "Allow mDNS/Bonjour: AirDrop, AirPlay, Handoff, printer discovery";
              };

              skipInterfaces = lib.mkOption {
                type = lib.types.listOf lib.types.str;
                default = [ "lo0" "awdl0" ];
                description = ''
                  Interfaces pf does not filter at all. lo0 is required.
                  awdl0 carries AirDrop, Handoff, Continuity, Sidecar and AirPlay
                  peer-to-peer, which use AWDL rather than ordinary mDNS — a
                  default deny breaks receiving on all of them unless skipped.
                '';
              };

              extraRules = lib.mkOption {
                type = lib.types.listOf lib.types.str;
                default = [ ];
                description = "Extra pf rules, inserted before the default deny";
              };

              tailscaleV4 = lib.mkOption {
                type = lib.types.str;
                default = "100.64.0.0/10";
                description = "Tailscale IPv4 CGNAT range. Rarely needs changing.";
              };

              tailscaleV6 = lib.mkOption {
                type = lib.types.str;
                default = "fd7a:115c:a1e0::/48";
                description = "Tailscale IPv6 ULA range. Rarely needs changing.";
              };
            };
          };
        };
      };
    };
  };
}
