# Inbound firewall for darwin — default deny, explicit allows.
#
# This is the macOS counterpart to NixOS's `networking.firewall`, which mynixos
# relies on for the same guarantee:
#
#   services.openssh.openFirewall = false;                                  # my/network/openssh
#   networking.firewall.interfaces.tailscale0.allowedTCPPorts = [ 22 ];     # my/network/openssh
#
# NixOS gives you default-deny input for free. macOS gives you neither that nor
# any per-interface control, so we build it on pf.
#
# WHY NOT THE APPLICATION FIREWALL: `networking.applicationFirewall` filters per
# APPLICATION at the socket layer, not per interface or port, and it has no
# allowlist — `--setblockall on` blocks sshd too. It is a useful complementary
# layer (it catches stray listeners) but it cannot express "deny inbound except
# SSH from the tailnet". Keep both.
#
# WHY NOT sshd_config: ListenAddress is INEFFECTIVE on macOS. Apple's
# /System/Library/LaunchDaemons/ssh.plist uses inetdCompatibility with
# `Sockets.Listeners.SockServiceName = "ssh"` and no SockNodeName, so launchd
# owns the listening socket, binds every interface, and hands each connection to
# sshd in inetd mode. Setting ListenAddress looks configured and restricts
# nothing.
#
# Rules key on DESTINATION/SOURCE ADDRESS rather than interface: the Tailscale
# tunnel has no stable interface name on macOS (a typical machine has many utun*
# devices and the Tailscale one is not identifiable by name), while Tailscale
# always assigns out of 100.64.0.0/10 and fd7a:115c:a1e0::/48. That also makes
# the rules survive the address changing, e.g. moving from a Tailscale SaaS
# tailnet to a self-hosted headscale.
{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.my.network.sshFirewall;

  anchorName = "org.mynixos.firewall";
  anchorFile = "/etc/pf.anchors/${anchorName}";

  ports = concatMapStringsSep ", " toString;

  # pf evaluates in order and the LAST matching rule wins -- except `quick`,
  # which wins immediately. So every allow is `quick` and the default deny sits
  # at the bottom without `quick`.
  anchorText = ''
    # Managed by mynixos (my/network/ssh-firewall/darwin.nix). Do not edit.

    # Return traffic for anything this machine initiated. Without this, a
    # default deny breaks all outbound connections' replies.
    pass out all keep state

    ${optionalString cfg.allowTailnet ''
    # The tailnet is trusted; authorization is enforced by the control server's
    # ACLs. ${if cfg.tailnetPorts == null then "All ports." else "Restricted to: ${ports cfg.tailnetPorts}."}
    ${if cfg.tailnetPorts == null then ''
    pass in quick from ${cfg.tailscaleV4} to any
    pass in quick from ${cfg.tailscaleV6} to any
    '' else ''
    pass in quick proto tcp to ${cfg.tailscaleV4} port { ${ports cfg.tailnetPorts} }
    pass in quick proto tcp to ${cfg.tailscaleV6} port { ${ports cfg.tailnetPorts} }
    ''}''}

    ${optionalString (cfg.tailscaleUdpPort != null) ''
    # Tailscale NAT traversal. WireGuard arrives ENCAPSULATED on the physical
    # interface, so it is not covered by the tailnet rules above. Without this,
    # direct peer-to-peer fails and everything falls back to DERP relays --
    # still functional, but slower and via Tailscale's servers.
    pass in quick proto udp to any port ${toString cfg.tailscaleUdpPort}
    ''}

    ${optionalString cfg.allowDhcp ''
    # DHCP client. Without this, leases may fail to renew on WiFi/Ethernet.
    pass in quick proto udp from any port 67 to any port 68
    ''}

    ${optionalString cfg.allowMdns ''
    # mDNS/Bonjour: AirDrop, AirPlay, Handoff/Continuity, printer discovery.
    pass in quick proto udp to any port 5353
    ''}

    ${concatMapStringsSep "\n" (r: "    ${r}") cfg.extraRules}

    # Default deny for everything else arriving from outside.
    block in all
  '';

  # Apple's own pf.conf, plus our anchor. Reproduced rather than appended
  # because an anchor must be REFERENCED from the main ruleset to be traversed
  # at all -- loading rules into an unreferenced anchor is a silent no-op.
  pfConfText = ''
    # Managed by mynixos. Based on Apple's default /etc/pf.conf.
    #
    # PF is not enabled automatically on macOS; each component enables it via
    # `pfctl -E` and releases it with -X. The launchd daemon below does that.

    set skip on { ${concatStringsSep ", " cfg.skipInterfaces} }

    #
    # com.apple anchor point (Apple's default ruleset, preserved verbatim)
    #
    scrub-anchor "com.apple/*"
    nat-anchor "com.apple/*"
    rdr-anchor "com.apple/*"
    dummynet-anchor "com.apple/*"
    anchor "com.apple/*"
    load anchor "com.apple" from "/etc/pf.anchors/com.apple"

    #
    # mynixos inbound policy
    #
    anchor "${anchorName}"
    load anchor "${anchorName}" from "${anchorFile}"
  '';
in
{
  config = mkIf cfg.enable {
    environment.etc."pf.anchors/${anchorName}".text = anchorText;

    environment.etc."pf.conf" = {
      text = pfConfText;
      # Apple's stock /etc/pf.conf. Without this, activation ABORTS rather than
      # moving the file aside -- see nix-darwin modules/system/etc.nix.
      knownSha256Hashes = [
        "6fb5b260918922ca5ca4dfb296967d8edb9c12f2c043f26b64590758441d682d"
      ];
    };

    # -E takes an enable reference so pf stays up; other components that use pf
    # hold their own references, and releasing ours will not tear theirs down.
    launchd.daemons.mynixos-pf = {
      serviceConfig = {
        Label = "org.mynixos.pf";
        RunAtLoad = true;
        KeepAlive = false;
        StandardErrorPath = "/var/log/mynixos-pf.log";
      };
      command = "${pkgs.writeShellScript "mynixos-pf-load" ''
        set -eu
        /sbin/pfctl -E -f /etc/pf.conf
      ''}";
    };
  };
}
