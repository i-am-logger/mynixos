{ config, lib, pkgs, ... }:

with lib;

{
  config = {
    home-manager.users = mapAttrs
      (name: userCfg:
        mkIf userCfg.apps.prompts.starship {
      programs.starship = {
        enable = true;
        settings = {
          "$schema" = "https://starship.rs/config-schema.json";

          # Main format - exactly like your TOML
          format = lib.concatStrings [
            "$shell $nix_shell"
            "$fill "
            "$direnv$pulumi$rust$nim$c$nodejs$golang"
            "$line_break"
            "$git_branch $git_commit $git_status $git_state"
            "$fill"
            "$username$hostname $battery "
            "$line_break"
            "$directory"
            "$fill"
            "$line_break"
            "$sudo$character "
          ];

          right_format = "";
          continuation_prompt = "[∙](bright-black) ";
          scan_timeout = 1;
          command_timeout = 500;
          add_newline = true;
          follow_symlinks = true;

          # AWS - from your TOML
          aws = {
            format = "on [$symbol($profile )(\\($region\\) )(\\[$duration\\] )]($style)";
            symbol = "☁️  ";
            style = "bold yellow";
            disabled = false;
            expiration_symbol = "X";
            force_display = false;
          };

          # Azure - from your TOML (disabled)
          azure = {
            format = "on [$symbol($subscription)]($style) ";
            symbol = "󰠅 ";
            style = "blue bold";
            disabled = true;
          };

          # Battery - exactly from your TOML
          battery = {
            full_symbol = "󰁹";
            charging_symbol = "󰂄";
            discharging_symbol = "󰂃";
            unknown_symbol = "󰁽";
            empty_symbol = "󰂎";
            disabled = false;
            format = "[$symbol]($style)";
            display = [
              { threshold = 20; style = "red bold"; }
              { threshold = 40; style = "yellow"; }
              { threshold = 60; style = "purple"; }
              { threshold = 80; style = "blue"; }
              { threshold = 100; style = ""; }
            ];
          };

          # Buf - from your TOML
          buf = {
            format = "with [$symbol($version )]($style)";
            symbol = "🐃 ";
            style = "bold blue";
            disabled = false;
            detect_files = [ "buf.yaml" "buf.gen.yaml" "buf.work.yaml" ];
          };

          # Bun - from your TOML
          bun = {
            format = "via [$symbol($version )]($style)";
            symbol = "🥟 ";
            style = "bold red";
            disabled = false;
            detect_files = [ "bun.lockb" "bunfig.toml" ];
          };

          # C - exactly from your TOML
          c = {
            format = " [$symbol($version(-$name))]($style)";
            style = "blue";
            symbol = " ";
            disabled = false;
            detect_extensions = [ "c" "h" ];
            detect_files = [ "configure.ac" ];
            detect_folders = [ ];
            commands = [ [ "cc" "--version" ] [ "gcc" "--version" ] [ "clang" "--version" ] ];
          };

          # Character - exactly from your TOML
          character = {
            format = "$symbol";
            success_symbol = "[](bold green)";
            error_symbol = "[](bold red)";
            vimcmd_symbol = "[❮](bold green)";
            vimcmd_visual_symbol = "[❮](bold yellow)";
            vimcmd_replace_symbol = "[❮](bold purple)";
            vimcmd_replace_one_symbol = "[❮](bold purple)";
            disabled = false;
          };

          # Cmake - from your TOML
          cmake = {
            format = "via [$symbol($version )]($style)";
            symbol = "△ ";
            style = "bold blue";
            disabled = false;
            detect_files = [ "CMakeLists.txt" "CMakeCache.txt" ];
          };

          # Cmd Duration - from your TOML
          cmd_duration = {
            min_time = 2000;
            format = "took [$duration]($style) ";
            style = "yellow bold";
            show_milliseconds = false;
            disabled = false;
            show_notifications = false;
            min_time_to_notify = 45000;
          };

          # Container - from your TOML
          container = {
            format = "[$symbol \\[$name\\]]($style) ";
            symbol = "⬢";
            style = "red bold dimmed";
            disabled = false;
          };

          # Directory - exactly from your TOML
          directory = {
            truncation_length = 3;
            truncate_to_repo = false;
            fish_style_pwd_dir_length = 3;
            use_logical_path = true;
            format = "[$read_only]($read_only_style)[$path]($style)";
            repo_root_format = "[$read_only]($read_only_style)[$before_root_path]($before_repo_root_style)[$repo_root]($repo_root_style)[$path]($style)";
            style = "white";
            repo_root_style = "underline cyan bold";
            disabled = false;
            read_only = "🔒";
            read_only_style = "red";
            truncation_symbol = "…/";
            home_symbol = " ~";
            use_os_path_sep = true;
          };

          # Docker Context - from your TOML
          docker_context = {
            symbol = "🐳 ";
            style = "blue bold";
            format = "via [$symbol$context]($style) ";
            only_with_files = true;
            disabled = false;
            detect_files = [ "docker-compose.yml" "docker-compose.yaml" "Dockerfile" ];
          };

          # Fill - exactly from your TOML
          fill = {
            style = "black";
            symbol = " ";
            disabled = false;
          };

          # GCloud - from your TOML
          gcloud = {
            format = "[$symbol$account(@$domain)(\\($region\\))]($style) ";
            symbol = "󱇶 ";
            style = "";
            disabled = false;
          };

          # Git branch - exactly from your TOML
          git_branch = {
            format = "[$symbol$branch(:$remote_branch)]($style)";
            symbol = " ";
            style = "cyan bold";
            truncation_length = 9223372036854775807;
            truncation_symbol = "…";
            only_attached = false;
            always_show_remote = false;
            ignore_branches = [ ];
            disabled = false;
          };

          # Git commit - exactly from your TOML
          git_commit = {
            commit_hash_length = 8;
            format = "[\\($hash$tag\\)]($style)";
            style = "blue";
            only_detached = false;
            disabled = false;
            tag_symbol = " 🏷  ";
            tag_disabled = false;
            tag_max_candidates = 0;
          };

          # Git metrics - from your TOML
          git_metrics = {
            added_style = "green";
            deleted_style = "red";
            only_nonzero_diffs = true;
            format = "([+$added]($added_style) )([-$deleted]($deleted_style))";
            disabled = false;
            ignore_submodules = false;
          };

          # Git state - exactly from your TOML
          git_state = {
            rebase = "REBASING";
            merge = "MERGING";
            revert = "REVERTING";
            cherry_pick = "CHERRY-PICKING";
            bisect = "BISECTING";
            am = "AM";
            am_or_rebase = "AM/REBASE";
            style = "bold yellow";
            format = "\\([$state( $progress_current/$progress_total)]($style)\\)";
            disabled = false;
          };

          # Git status - exactly from your TOML with all custom symbols
          git_status = {
            format = "([$ahead_behind$all_status]($style))";
            style = "";
            stashed = "[\${count}](cyan) ";
            ahead = "[󱓍 ⇡\${count}](purple) ";
            behind = "[󱓍 ⇣\${count}](red) ";
            up_to_date = "[󱓏](green) ";
            diverged = "[󰩌 \${count}](red) ";
            conflicted = "[ \${count}](red) ";
            deleted = "[󱪢 \${count}](green) ";
            renamed = "[󱀱 \${count}](green) ";
            modified = "[ \${count}](red) ";
            staged = "[󰸩 \${count}](green) ";
            untracked = "[󱀶 \${count}](red) ";
            typechanged = "type \${count}(yellow)";
            ignore_submodules = false;
            disabled = false;
          };

          # Go - exactly from your TOML
          golang = {
            format = "[$symbol]($style)";
            symbol = "";
            style = "";
            disabled = false;
            not_capable_style = "bold red";
            detect_extensions = [ "go" ];
            detect_files = [ "go.mod" "go.sum" "go.work" "glide.yaml" "Gopkg.yml" "Gopkg.lock" ".go-version" ];
            detect_folders = [ "Godeps" ];
          };

          # Hostname - exactly from your TOML
          hostname = {
            ssh_only = true;
            ssh_symbol = " 󰣀";
            trim_at = ".";
            detect_env_vars = [ ];
            format = "[@$hostname$ssh_symbol]($style)";
            style = "bold yellow";
            disabled = false;
          };

          # Jobs - from your TOML
          jobs = {
            threshold = 1;
            symbol_threshold = 1;
            number_threshold = 2;
            format = "[$symbol$number]($style) ";
            symbol = "✦";
            style = "bold blue";
            disabled = false;
          };

          # Line break
          line_break = {
            disabled = false;
          };

          # Memory usage - from your TOML (disabled)
          memory_usage = {
            threshold = 75;
            format = "via $symbol[$ram( | $swap)]($style) ";
            style = "white bold dimmed";
            symbol = "🐏 ";
            disabled = true;
          };

          # Nim - exactly from your TOML
          nim = {
            format = "[$symbol]($style)";
            symbol = " ";
            style = "";
            disabled = false;
            detect_extensions = [ "nim" "nims" "nimble" ];
            detect_files = [ "nim.cfg" ];
            detect_folders = [ ];
          };

          # Nix shell - exactly from your TOML
          nix_shell = {
            format = "[$symbol$state]($style)";
            symbol = " ";
            style = "bold yellow";
            impure_msg = "impure!";
            pure_msg = "pure";
            unknown_msg = "unknown";
            disabled = false;
            heuristic = false;
          };

          # Node.js - exactly from your TOML
          nodejs = {
            format = " [$symbol]($style)";
            symbol = " ";
            style = "";
            disabled = false;
            not_capable_style = "bold red";
            detect_extensions = [ "js" "mjs" "cjs" "ts" "mts" "cts" ];
            detect_files = [ "package.json" ".node-version" ".nvmrc" ];
            detect_folders = [ "node_modules" ];
          };

          # OS - from your TOML
          os = {
            format = "[$symbol]($style)";
            style = "bold white";
            disabled = false;
            symbols = {
              AIX = "➿ ";
              Alpaquita = "🔔 ";
              AlmaLinux = "💠 ";
              Alpine = "🏔️ ";
              Amazon = "🙂 ";
              Android = "🤖 ";
              Arch = "🎗️ ";
              Artix = "🎗️ ";
              CentOS = "💠 ";
              Debian = "🌀 ";
              DragonFly = "🐉 ";
              Emscripten = "🔗 ";
              EndeavourOS = "🚀 ";
              Fedora = "🎩 ";
              FreeBSD = "😈 ";
              Garuda = "🦅 ";
              Gentoo = "🗜️ ";
              HardenedBSD = "🛡️ ";
              Illumos = "🐦 ";
              Kali = "🐉 ";
              Linux = "🐧 ";
              Mabox = "📦 ";
              Macos = "🍎 ";
              Manjaro = "🥭 ";
              Mariner = "🌊 ";
              MidnightBSD = "🌘 ";
              Mint = "🌿 ";
              NetBSD = "🚩 ";
              NixOS = "❄️ ";
              OpenBSD = "🐡 ";
              OpenCloudOS = "☁️ ";
              openEuler = "🦉 ";
              openSUSE = "🦎 ";
              OracleLinux = "🦴 ";
              Pop = "🍭 ";
              Raspbian = "🍓 ";
              Redhat = "🎩 ";
              RedHatEnterprise = "🎩 ";
              RockyLinux = "💠 ";
              Redox = "🧪 ";
              Solus = "⛵ ";
              SUSE = "🦎 ";
              Ubuntu = "🎯 ";
              Ultramarine = "🔷 ";
              Unknown = "❓ ";
              Void = "  ";
              Windows = "🪟 ";
            };
          };

          # Package - from your TOML
          package = {
            format = "is [$symbol$version]($style) ";
            symbol = "📦 ";
            style = "208 bold";
            display_private = false;
            disabled = false;
          };

          # Pulumi - exactly from your TOML
          pulumi = {
            format = "[$symbol$project$stack]($style)";
            symbol = " ";
            style = "";
            disabled = false;
            search_upwards = true;
          };

          # Rust - exactly from your TOML
          rust = {
            format = "[$symbol]($style)";
            symbol = " ";
            style = "";
            disabled = false;
            detect_extensions = [ "rs" ];
            detect_files = [ "Cargo.toml" ];
            detect_folders = [ ];
          };

          # Shell - exactly from your TOML
          shell = {
            format = "[$indicator]($style)";
            bash_indicator = "";
            fish_indicator = " ";
            zsh_indicator = "zsh";
            powershell_indicator = "psh";
            ion_indicator = "ion";
            elvish_indicator = "esh";
            tcsh_indicator = "tsh";
            nu_indicator = "nu";
            xonsh_indicator = "xsh";
            cmd_indicator = "cmd";
            unknown_indicator = "";
            style = "";
            disabled = false;
          };

          # Status - from your TOML (disabled)
          status = {
            format = "[$symbol$status]($style) ";
            symbol = "❌";
            success_symbol = "";
            not_executable_symbol = "🚫";
            not_found_symbol = "🔍";
            sigint_symbol = "🧱";
            signal_symbol = "⚡";
            style = "bold red";
            map_symbol = false;
            recognize_signal_code = true;
            pipestatus = false;
            pipestatus_separator = "|";
            disabled = true;
          };

          # Sudo - exactly from your TOML
          sudo = {
            format = "[$symbol]($style)";
            symbol = "󰀋 ";
            style = "bold yellow";
            allow_windows = false;
            disabled = false;
          };

          # Time - from your TOML
          time = {
            format = "[$time]($style)";
            style = "blue";
            use_12hr = false;
            disabled = false;
            utc_time_offset = "local";
            time_range = "-";
          };

          # Username - exactly from your TOML
          username = {
            detect_env_vars = [ ];
            format = "[$user]($style)";
            style_root = "bold red";
            style_user = "bold yellow";
            show_always = false;
            disabled = false;
          };

          # Direnv - exactly from your TOML
          direnv = {
            format = "[$allowed]($style)";
            symbol = "";
            style = "bold red";
            disabled = false;
            detect_files = [ ".envrc" ];
            allowed_msg = "";
            not_allowed_msg = " ";
            denied_msg = " ";
            loaded_msg = "";
            unloaded_msg = "";
          };
        };
      };
        }
      )
      config.my.users;
  };
}
