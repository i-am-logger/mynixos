{ config
, lib
, ...
}:

with lib;

let
  cfg = config.my.network.ipv6.privacy;
in
{
  config = mkIf cfg.enable {
    # nixpkgs maps "default" → use_tempaddr=2 (generate AND prefer), and
    # "enabled" → 1 (generate but still emit from EUI-64). Counter-intuitive,
    # but "default" is what we want for outbound privacy.
    networking.tempAddresses = "default";

    boot.kernel.sysctl = {
      # nixpkgs only sets `default.use_tempaddr` (template for new interfaces).
      # Set `all` too so already-up interfaces flip without reboot.
      "net.ipv6.conf.all.use_tempaddr" = 2;

      "net.ipv6.conf.all.temp_prefered_lft" = cfg.preferredLifetime;
      "net.ipv6.conf.default.temp_prefered_lft" = cfg.preferredLifetime;
      "net.ipv6.conf.all.temp_valid_lft" = cfg.validLifetime;
      "net.ipv6.conf.default.temp_valid_lft" = cfg.validLifetime;
      "net.ipv6.conf.all.max_desync_factor" = cfg.maxDesyncFactor;
      "net.ipv6.conf.default.max_desync_factor" = cfg.maxDesyncFactor;

      "net.ipv6.conf.all.addr_gen_mode" = cfg.addrGenMode;
      "net.ipv6.conf.default.addr_gen_mode" = cfg.addrGenMode;
    };

    assertions = [
      {
        # Kernel disables tempaddr when prefered_lft <= regen_advance + max_desync_factor.
        # regen_advance is ~3s with default retry/dad/retrans values; require 5s of headroom.
        assertion = cfg.preferredLifetime > cfg.maxDesyncFactor + 5;
        message = ''
          my.network.ipv6.privacy: preferredLifetime (${toString cfg.preferredLifetime}s) must
          exceed maxDesyncFactor (${toString cfg.maxDesyncFactor}s) by more than ~5s, otherwise
          the kernel silently disables temporary address generation.
        '';
      }
      {
        assertion = cfg.validLifetime > cfg.preferredLifetime;
        message = ''
          my.network.ipv6.privacy: validLifetime (${toString cfg.validLifetime}s) must be
          strictly greater than preferredLifetime (${toString cfg.preferredLifetime}s) so
          in-flight connections survive past the next rotation.
        '';
      }
    ];
  };
}
