# herdr's entry in the terminal.multiplexer enum, the default for the enum
# as a whole, and herdr's own settings and plugins.
#
# The default lives here rather than in my/users/terminal/options.nix because
# this is mynixos's opinion about herdr specifically: this fleet runs coding
# agents, and herdr is the only member of the enum that shows which agent is
# running, which is waiting on you, and which is done. Drop herdr from
# platforms/common.nix and the option loses its default, which surfaces as a
# loud "used but not defined" -- the right failure, not a silent fallback to
# something nobody chose.
#
# Only one declaration may carry a default (mergeOptionDecls rejects a second),
# so this file and the base declaration are not interchangeable.
#
# Settings and plugins sit under terminal.herdr rather than apps.*: herdr is
# selected, not switched on, and has no apps.* option by design (CLAUDE.md,
# "App configuration"). They are read only when multiplexer == "herdr".
#
# herdr-focus-notify is macOS-only (its manifest declares `platforms =
# ["macos"]`), so its option is declared in ./options-darwin.nix.
{ lib, ... }:

let
  # A herdr binding (`[[keys.command]]`). ./default.nix asserts that no two
  # plugin keys are equal and that none is one of herdr's built-in bindings.
  key = default: what: lib.mkOption {
    type = lib.types.nonEmptyStr;
    inherit default;
    description = ''
      herdr key that ${what}, in herdr's binding syntax ("prefix+a",
      "cmd+r"). It must not be a herdr built-in (`herdr --default-config`,
      [keys]) or another plugin's key.
    '';
  };
in
{
  options.my.users = lib.mkOption {
    type = lib.types.attrsOf (lib.types.submodule {
      options.terminal = lib.mkOption {
        type = lib.types.submodule {
          options = {
            multiplexer = lib.mkOption {
              type = lib.types.enum [ "herdr" ];
              default = "herdr";
            };

            herdr = {
              statusIndicators = lib.mkOption {
                type = lib.types.enum [ "dots" "symbols" ];
                default = "dots";
                description = ''
                  herdr's agent status marks (`[ui] status_indicators`): "dots"
                  are compact colour marks, "symbols" a distinct glyph per state
                  (blocked, working, done, idle, unknown).
                '';
              };

              plugins = {
                projects = {
                  enable = lib.mkEnableOption ''
                    the herdr-projects plugin (a coordinator conversation,
                    parallel worker threads, shared memory). Linked into herdr on
                    every activation; its sidebar rows, tab-bar entry and popup
                    key are written into config.toml. Its Claude Code progress
                    hooks and skill link are not installed
                  '';
                  popupKey = key "prefix+a" "opens the Projects popup (the plugin's own default)";
                };

                clauth = {
                  enable = lib.mkEnableOption ''
                    clauth's herdr plugin: an accounts popup and a per-pane
                    account tag in the sidebar. Requires apps.ai.tools.clauth
                  '';
                  # clauth's own default is prefix+a, which is herdr-projects'.
                  popupKey = key "prefix+u" "opens the clauth popup";
                };

                radar = {
                  enable = lib.mkEnableOption ''
                    the herdr-radar plugin. It publishes its own pane and Space
                    tokens and a tab-bar summary; only the tab-bar entry is
                    written into config.toml, because the sidebar rows belong to
                    herdr-projects. Its daemon still sets herdr's agent view on
                    every start
                  '';
                };

                usage = {
                  enable = lib.mkEnableOption ''
                    the Claude plan usage gauge (herdr-claude-usage-multi):
                    Session/Week percentages on every Space row. It reads the
                    global Claude Code login, so with clauth it follows
                    whichever profile clauth has switched to
                  '';
                  # The plugin's README suggests prefix+u, which clauth has.
                  popupKey = key "prefix+shift+u" "opens the usage popup";
                };

                reviewr = {
                  enable = lib.mkEnableOption ''
                    the reviewr plugin: review an agent's diff beside the chat
                    and send line comments to its input
                  '';
                  toggleKey = key "cmd+r" "toggles the reviewr pane (the plugin README's suggestion)";
                };
              };
            };
          };
        };
      };
    });
  };
}
