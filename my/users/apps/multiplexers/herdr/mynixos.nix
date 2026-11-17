# mynixos's opinion about herdr's plugins: clauth's plugin is on wherever
# clauth is and herdr is the multiplexer (owner, 2026-11-17). A user's
# explicit `false` still wins; without clauth it stays off, since the plugin
# asserts apps.ai.tools.clauth.enable.
{ lib, ... }:

{
  options.my.users = lib.mkOption {
    type = lib.types.attrsOf (lib.types.submodule ({ config, ... }: {
      config.terminal.herdr.plugins.clauth.enable = lib.mkDefault
        ((config.apps.ai.tools.clauth.enable or false)
          && config.terminal.multiplexer == "herdr");
    }));
  };
}
