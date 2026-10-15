# herdr, a terminal multiplexer built around running coding agents side by side.
#
# Gated on `terminal.multiplexer == "herdr"`, the same selector tmux and zellij
# use, and for the same reason: a second on/off switch beside the selector is a
# second way to say one thing. Its enum member, the enum's default, its
# settings and its plugins are declared in ./options.nix.
#
# Unlike tmux and zellij, home-manager has no programs.herdr module, so this one
# puts the package on PATH and writes the config file itself.
#
# Plugins. A plugin cannot declare keys, sidebar rows or tab-bar entries; its
# installer edits config.toml instead, which is a store link here and refuses
# (herdr-projects src/setup.rs:93-95). So what each installer would have
# written is written here, and each plugin is registered with herdr from
# activation (./plugin-registry.nix). Nothing here writes herdr's plugins.json.
{ activeUsers, config, lib, pkgs, ... }:

with lib;

let
  isHerdr = userCfg: (userCfg.terminal.multiplexer or null) == "herdr";

  registry = import ./plugin-registry.nix { inherit lib pkgs; };
  inherit (registry) rootOf;

  packages = {
    projects = pkgs.callPackage ../../../../../packages/herdr-projects { };
    clauth = pkgs.callPackage ../../../../../packages/clauth { };
    radar = pkgs.callPackage ../../../../../packages/herdr-radar { };
    usage = pkgs.callPackage ../../../../../packages/herdr-claude-usage-multi { };
    reviewr = pkgs.callPackage ../../../../../packages/herdr-reviewr { };
  };

  # herdr 0.9.5's built-in bindings with a default (`herdr --default-config`,
  # [keys]; src/config/keys). `prefix+1..9` (switch_tab) is expanded, and
  # ctrl+v is remote_image_paste. A plugin key equal to one of these would
  # shadow or be shadowed by a herdr action.
  builtinKeys = [
    "ctrl+b"
    "prefix+?"
    "prefix+s"
    "prefix+q"
    "prefix+shift+r"
    "prefix+o"
    "prefix+w"
    "prefix+g"
    "prefix+shift+n"
    "prefix+shift+g"
    "prefix+shift+w"
    "prefix+shift+d"
    "ctrl+v"
    "prefix+c"
    "prefix+shift+t"
    "prefix+p"
    "prefix+n"
    "prefix+shift+x"
    "prefix+shift+p"
    "prefix+e"
    "prefix+h"
    "prefix+j"
    "prefix+k"
    "prefix+l"
    "prefix+tab"
    "prefix+shift+tab"
    "prefix+v"
    "prefix+minus"
    "prefix+x"
    "prefix+z"
    "prefix+r"
    "prefix+b"
  ] ++ map (n: "prefix+${toString n}") (range 1 9);

  # Every enabled plugin key as { owner, key }, for the collision checks.
  pluginKeys = plugins:
    optional plugins.projects.enable { owner = "projects.popupKey"; key = plugins.projects.popupKey; }
    ++ optional plugins.clauth.enable { owner = "clauth.popupKey"; key = plugins.clauth.popupKey; }
    ++ optional plugins.usage.enable { owner = "usage.popupKey"; key = plugins.usage.popupKey; }
    ++ optional plugins.reviewr.enable { owner = "reviewr.toggleKey"; key = plugins.reviewr.toggleKey; };

  anyPlugin = plugins:
    any (n: plugins.${n}.enable) (attrNames packages);

  # Nix strings have no \u escape; JSON does. These are herdr-projects' two
  # invisible group marks (src/grouping.rs:22,25): HEAD_MARK U+200B ends a
  # coordinator's agent name, HOME_MARK U+2800 a project's home Space label.
  headMark = builtins.fromJSON ''"​"'';
  homeMark = builtins.fromJSON ''"⠀"'';

  # herdr-projects' agent card and sub-line, exactly as its `configure` writes
  # them into a config with no rows of its own (src/sidebar.rs:212-281,
  # :404-425); checked against a sandboxed `configure` run.
  projectsAgentCard = [
    "state_icon"
    { token = "agent"; bold = false; dim = false; rules = [{ contains = headMark; bold = true; }]; }
    "state_text"
  ];
  projectsSubRow = [{ token = "$hp_sub"; dim = true; }];
  projectsSpaceCard = [
    "state_icon"
    { token = "workspace"; rules = [{ contains = homeMark; bold = true; }]; }
    { token = "branch"; dim = true; }
    "git_status"
  ];

  # herdr-claude-usage-multi's Space rows (its README), one gauge state each.
  usageSpaceRows = [
    [{ token = "$cu"; fg = "#a6e3a1"; }]
    [{ token = "$cu_warn"; fg = "#f9e2af"; }]
    [{ token = "$cu_hot"; fg = "#f38ba8"; bold = true; }]
    [{ token = "$cu_out"; fg = "#f38ba8"; bold = true; }]
  ];

  # `herdr --default-config` is the schema of record. Only settings that would
  # otherwise be WRONG for a Nix-managed install, or that an option chooses,
  # are stated; herdr's own defaults are left unsaid.
  settingsFor = { home, stateHome }: userCfg:
    let
      herdrCfg = userCfg.terminal.herdr;
      inherit (herdrCfg) plugins;
      on = name: plugins.${name}.enable;
      radarState = "${stateHome}/herdr/plugins/${packages.radar.pluginId}";
    in
    foldl' recursiveUpdate { } [
      {
        # A declarative install has already made every choice the wizard asks about.
        onboarding = false;

        theme = {
          # Follow the host terminal's light/dark appearance rather than pinning one.
          auto_switch = true;
          dark_name = "catppuccin";
          light_name = "catppuccin-latte";
        };

        terminal = optionalAttrs (userCfg.shell != null) {
          # mynixos DECLARES the shell (my/users/users/mynixos-darwin.nix makes it
          # zsh, mynixos-linux.nix bash) but deliberately leaves a macOS account's
          # login shell alone -- so $SHELL, which is herdr's own fallback, is
          # whatever Setup Assistant left in the directory service. Naming it makes
          # herdr's panes honour the declaration instead of the directory service.
          default_shell = userCfg.shell;
        };

        update = {
          # The binary is a read-only store path. It cannot self-update, so this
          # poll to herdr.dev could only ever tell us what the next lock bump would.
          version_check = false;

          # A different thing, off for a different reason: this one fetches
          # agent-DETECTION manifests, so switching it off is a real trade -- herdr
          # stops learning to recognise agents released after the pinned version, in
          # exchange for making no unbidden network call. Turn it back on if
          # detection goes stale before the next nixpkgs bump.
          manifest_check = false;
        };

        # Stated even at herdr's own default, because it is an option: the
        # file then says what was chosen.
        ui.status_indicators = herdrCfg.statusIndicators;
      }

      (optionalAttrs (pluginKeys plugins != [ ]) {
        keys.command =
          optional (on "projects")
            {
              key = plugins.projects.popupKey;
              type = "plugin_action";
              command = "herdr-projects.open-popup";
              description = "Projects";
            }
          ++ optional (on "clauth") {
            key = plugins.clauth.popupKey;
            type = "plugin_action";
            command = "clauth.open";
            description = "clauth accounts";
          }
          # The plugin's pane, opened the way its README does: herdr sets
          # HERDR_BIN_PATH to its own binary for every command it runs.
          ++ optional (on "usage") {
            key = plugins.usage.popupKey;
            type = "shell";
            command = ''"$HERDR_BIN_PATH" plugin pane open --plugin ${packages.usage.pluginId} --entrypoint usage'';
            description = "Claude usage";
          }
          ++ optional (on "reviewr") {
            key = plugins.reviewr.toggleKey;
            type = "plugin_action";
            command = "${packages.reviewr.pluginId}.toggle";
            description = "reviewr";
          };
      })

      # tab_bar_right is an array, so each plugin's entry sits beside the
      # other's. The store path, not a profile link: this file is regenerated
      # with the package, so the two can never disagree.
      (optionalAttrs (on "projects" || on "radar") {
        ui.tab_bar_right =
          optional (on "projects")
            {
              type = "command";
              command = "${packages.projects}/bin/herdr-projects --root ${home}/.herdr-projects needs-you --line";
              interval_seconds = 15;
              timeout_seconds = 5;
            }
          # radar's daemon writes the summary to its state directory every 2 s;
          # this only reads it. ''${ keeps the shell's parameter expansion.
          ++ optional (on "radar") {
            type = "command";
            command = ''cat "${radarState}/tabbar''${HERDR_SESSION:+-$HERDR_SESSION}.txt"'';
            interval_seconds = 6;
            timeout_seconds = 2;
          };
      })

      (optionalAttrs (on "radar") {
        ui.tab_bar_right_separator = " · ";
      })

      (optionalAttrs (on "projects") {
        ui.sidebar.agents.rows = [ projectsAgentCard projectsSubRow ];
      })

      # One Spaces card: herdr-projects' row, then the usage gauges.
      (optionalAttrs (on "projects" || on "usage") {
        ui.sidebar.spaces.rows =
          optional (on "projects") projectsSpaceCard
          ++ optionals (on "usage") usageSpaceRows;
      })

      # rows_by_agent.claude REPLACES `rows` for every Claude pane -- here,
      # nearly every pane. clauth's own row (herdr-plugin/README.md) would drop
      # herdr-projects' card and sub-line wherever both are on, so the combined
      # form keeps the card, appends $clauth, and keeps the sub-line.
      (optionalAttrs (on "clauth") {
        ui.sidebar.agents.rows_by_agent.claude =
          if on "projects"
          then [ (projectsAgentCard ++ [ "$clauth" ]) projectsSubRow ]
          else [
            [ "state_icon" "workspace" "tab" ]
            [ "terminal_title_stripped" ]
            [ "agent" "$clauth" ]
          ];
      })
    ];

  configFor = paths: userCfg:
    (pkgs.formats.toml { }).generate "herdr-config.toml" (settingsFor paths userCfg);

in
{
  config = {
    assertions = concatLists (mapAttrsToList
      (name: userCfg:
        let
          inherit (userCfg.terminal.herdr) plugins;
          keys = pluginKeys plugins;
          normalised = map (k: toLower k.key) keys;
          enabled = filter (n: plugins.${n}.enable) (attrNames packages);
        in
        optionals (isHerdr userCfg) (
          # herdr refuses to link a plugin newer than itself (docs/plugins.mdx).
          # 0.9.1 is herdr-projects' floor and the oldest herdr this module's
          # plugin wiring was checked against; nixpkgs ships 0.9.0.
          [{
            assertion = !(anyPlugin plugins) || versionAtLeast pkgs.herdr.version "0.9.1";
            message = "my.users.${name}.terminal.herdr.plugins need herdr >= 0.9.1; pkgs.herdr is ${pkgs.herdr.version}";
          }]
          ++ map
            (n: {
              assertion = versionAtLeast pkgs.herdr.version packages.${n}.minHerdrVersion;
              message = "my.users.${name}.terminal.herdr.plugins.${n} needs herdr >= ${packages.${n}.minHerdrVersion}; pkgs.herdr is ${pkgs.herdr.version}";
            })
            enabled
          ++ [
            {
              assertion = !plugins.clauth.enable || userCfg.apps.ai.tools.clauth.enable;
              message = "my.users.${name}.terminal.herdr.plugins.clauth needs apps.ai.tools.clauth.enable";
            }
            {
              assertion = length (unique normalised) == length normalised;
              message = "my.users.${name}.terminal.herdr.plugins: two plugins bind one key (${concatMapStringsSep ", " (k: "${k.owner} = ${k.key}") keys})";
            }
          ]
          ++ map
            (k: {
              assertion = !(elem (toLower k.key) builtinKeys);
              message = "my.users.${name}.terminal.herdr.plugins.${k.owner} = \"${k.key}\" is a herdr built-in binding";
            })
            keys
        ))
      (activeUsers config.my.users));

    home-manager.users = mapAttrs
      (_name: userCfg:
        { lib, ... }@hm:
        let
          home = hm.config.home.homeDirectory;
          configHome = hm.config.xdg.configHome;
          stateHome = hm.config.xdg.stateHome;
          inherit (userCfg.terminal.herdr) plugins;
        in
        lib.mkIf (isHerdr userCfg) (lib.mkMerge [
          {
            home.packages = [ pkgs.herdr ];

            # The file, never the directory: herdr writes session.json,
            # session-history.json and plugins.json next to config.toml, so
            # ~/.config/herdr has to stay a real, writable directory.
            # xdg.configFile symlinks per file, which is exactly what that needs.
            #
            # Consequence worth knowing: config.toml is a store path, so herdr's
            # own settings screen cannot save to it, and neither can a plugin's
            # installer. Settings changes come back here as Nix.
            xdg.configFile."herdr/config.toml".source = configFor { inherit home stateHome; } userCfg;

            # Runs after linkGeneration so a new config.toml is in place first.
            # Every plugin is listed, on or off, so turning one off unlinks it.
            home.activation.herdrPlugins = lib.hm.dag.entryAfter [ "linkGeneration" ] (registry.script {
              inherit configHome stateHome;
              plugins = mapAttrsToList
                (n: pkg: { id = pkg.pluginId; root = rootOf pkg; inherit (plugins.${n}) enable; })
                packages;
            });
          }

          (lib.mkIf plugins.projects.enable {
            home.packages = [ packages.projects ];

            # The plugin links ~/.local/bin/herdr-projects to its own binary at
            # every start, and leaves alone any link that resolves to the
            # running binary (src/command_link.rs:42-61, src/cli.rs:871-877).
            # Its own link would name a store path and keep naming it after an
            # upgrade; this one goes through the home-manager generation, always
            # resolves to the current binary, and so is never rewritten.
            # `force` replaces the link an earlier install left there.
            home.file.".local/bin/herdr-projects" = {
              source = "${packages.projects}/bin/herdr-projects";
              force = true;
            };
          })

          (lib.mkIf plugins.radar.enable {
            # radar's own settings (<herdr config dir>/plugins/config/<id>).
            # follow_appearance off: on, it runs theme-sync every 60 s and on a
            # light/dark flip writes [theme] name and auto_switch = false into
            # config.toml, fighting auto_switch above (and failing on the store
            # link). variant "text": the font variant needs radar's own hashed
            # font copy in ~/Library/Fonts, which nothing here installs.
            # A store link, so saving from radar's settings popup fails.
            xdg.configFile."herdr/plugins/config/${packages.radar.pluginId}/config.toml".source =
              (pkgs.formats.toml { }).generate "herdr-radar-config.toml" {
                follow_appearance = false;
                variant = "text";
              };
          })

          # Layouts call `herdr-reviewr` by name.
          (lib.mkIf plugins.reviewr.enable {
            home.packages = [ packages.reviewr ];
          })
        ]))
      (activeUsers config.my.users);
  };
}
