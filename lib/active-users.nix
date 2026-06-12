# A user is "active" (fully configured -> created as a NixOS user) when it has a
# fullName. Single source of truth, shared by lib/default.nix (which exposes the
# public `mynixos.lib.activeUsers` / the `activeUsers` _module.arg) and
# lib/mk-app.nix (which self-computes it to stay independent of _module.args).
lib: lib.filterAttrs (_: u: u.fullName or null != null)
