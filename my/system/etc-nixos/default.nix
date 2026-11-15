# /etc/nixos as a link to the host's flake checkout (my.system.etcNixos.link).
#
# Never by removing what is there. tmpfiles' `L+` would remove an existing
# /etc/nixos first, and on an impermanence host that path is a bind mount of
# /persist/etc/nixos, so the removal would go through to the persisted copy.
# Instead the link is made only where nothing can be lost:
#
#   * absent: made.
#   * already a link: re-pointed (ln -sfn replaces the link, never its target).
#   * a directory: `rmdir`, which refuses anything with contents (ENOTEMPTY)
#     and a live mount point (EBUSY), then made.
#   * anything else: left as it is, with a warning.
#
# Live, switch-to-configuration stops the units it no longer has before it
# runs activation, so a dropped persistence mount is normally gone by then and
# its empty mount point is replaced on the spot. If the mount is still there,
# the rmdir refuses and the link appears on the next boot, when a tmpfs root
# has no /etc/nixos at all.
#
# Imported only by platforms/linux.nix.
{ config, lib, ... }:

with lib;

let
  inherit (config.my.system.etcNixos) link;
in
{
  config = mkIf (link != null) {
    assertions = [{
      assertion = hasPrefix "/" link;
      message = "my.system.etcNixos.link must be an absolute path, got: ${link}";
    }];

    system.activationScripts.etcNixosLink = {
      text = ''
        target=${escapeShellArg link}
        if [ -L /etc/nixos ] || [ ! -e /etc/nixos ]; then
          ln -sfn "$target" /etc/nixos
        elif [ -d /etc/nixos ] && rmdir /etc/nixos 2>/dev/null; then
          ln -s "$target" /etc/nixos
        else
          echo "warning: /etc/nixos is not empty or is still mounted; leaving it, and not linking it to $target." >&2
          echo "warning: on a tmpfs root the link is made at the next boot." >&2
        fi
      '';
      deps = [ "specialfs" ];
    };
  };
}
