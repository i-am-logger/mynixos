{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.my.apps.editors.helix;
in
{

  config = mkIf cfg {
    home-manager.users = mapAttrs (name: userCfg: {
      home.packages = with pkgs; [
        helix
        alejandra

        # pkgs.nodePackages.bash-language-server
        cmake-language-server
        marksman
        markdown-oxide

        # zellij
        # lazygit
        nil
        # pkgs.rnix-lsp
        rust-analyzer
        lldb
        clang-tools
        # ocamlPackages.ocaml-lsp
        vscode-langservers-extracted
        # dockerfile-language-server-nodejs
        # haskellPackages.haskell-language-server
        # nodePackages.typescript-language-server
        texlab
        # lua-language-server
        # marksman
        # pkgs.nodePackages.pyright
        # pkgs.python310Packages.python-lsp-server
        # nodePackages.vue-language-server
        yaml-language-server
        taplo
        gh-copilot
        # pkgs.vimPlugins.copilot-vim
        tree-sitter
        (tree-sitter.withPlugins (_: tree-sitter.allGrammars))
        # nixpkgs-fmt
        # nixfmt
        nixfmt-rfc-style
        # nixpkgs-fmt
      ];

      programs.helix = {
        enable = true;
        defaultEditor = true;
        settings = {
          editor = {
            # line-number = "relative";
            rulers = [ 120 ];
            bufferline = "always";
            mouse = true;
            true-color = true;
            color-modes = true;
            cursorline = true;
            auto-completion = true;
            completion-trigger-len = 1;

            end-of-line-diagnostics = "hint";
            inline-diagnostics = {
              cursor-line = "error";
            };
            cursor-shape = {
              insert = "bar";
              normal = "block";
              select = "underline";
            };
            file-picker = {
              hidden = false;
              git-ignore = true;
            };
            soft-wrap = {
              enable = true;
            };
            statusline = {
              left = [
                "mode"
                "file-name"
                "spinner"
              ];
              center = [ "position-percentage" ];
              right = [
                "version-control"
                "diagnostics"
                "selections"
                "position"
                "file-encoding"
                "file-line-ending"
                "file-type"
              ];
              separator = "│";
            };
            lsp = {
              enable = true;
              display-messages = true;
              auto-signature-help = true;
              # display-inlay-hints = true;
              display-signature-help-docs = true;
              snippets = true;
              goto-reference-include-declaration = true;
            };
            whitespace = {
              render = "all";
              characters = {
                space = " ";
                nbsp = "⍽";
                tab = "→";
                # newline = "⏎";
                tabpad = " "; # "·"; # Tabs will look like "→···" (depending on tab width)
              };
            };
            indent-guides = {
              render = true;
              character = "│"; # "╎";
            };
          };
          keys.normal = {
            esc = [
              "collapse_selection"
              "keep_primary_selection"
            ];
            J = [
              "delete_selection"
              "paste_after"
            ];
            K = [
              "delete_selection"
              "move_line_up"
              "paste_before"
            ];
            C-u = [
              "half_page_up"
              "align_view_center"
            ];
            C-d = [
              "half_page_down"
              "align_view_center"
            ];

            "[" = "goto_previous_buffer";
            "]" = "goto_next_buffer";

            g = {
              x = ":buffer-close";
              j = "jump_backward";
              k = "jump_forward";
            };
            space = {
              l = ":toggle lsp.display-inlay-hints";
              n = ":toggle lsp.auto-signature_help";

              space.space = "file_picker";
              space.w = ":w";
              space.q = ":q";
            };

            backspace = {
              b = {
                r = ":run-shell-command zellij run -fc -- cargo build";
                n = ":run-shell-command zellij run -f -- nix build";
              };

              d = {
                d = ":run-shell-command zellij run -fc -- watch --color -n 0.2 lsd /dev/ttyACM* -h --color always";
                b = ":run-shell-command zellij run -fc -- btop";
              };

              r = {
                n = ":run-shell-command zellij run -f -- nix run";
                r = ":run-shell-command zellij run -fc -- cargo run";
              };

              t = {
                n = ":run-shell-command zellij run -f -- nix test";
                r = ":run-shell-command zellij run -fc -- cargo test";
              };

              g = ":run-shell-command zellij run -fc -- lazygit";
              f = ":run-shell-command zellij run -fc -- broot";
            };
          };
        };
        languages = {

          language-server =
            with pkgs;
            with pkgs.nodePackages_latest;
            {
              typescript-language-server = {
                command = "${typescript-language-server}/bin/typescript-language-server";
                args = [ "--stdio" ];
              };
              svelteserver.command = "${svelte-language-server}/bin/svelteserver";
              tailwindcss-ls.command = "${tailwindcss-language-server}/bin/tailwindcss-language-server";
              # nixd = {
              #   command = "${nixd}/bin/nixd";
              # };
              # eslint = {
              #   command = "${eslint}/bin/eslint";
              #   args = [ "--stdin" ];
              # };
              copilot = {
                command = "github-copilot-cli";
                args = [ "--stdio" ];
              };
              nil.command = "${nil}/bin/nil";
              rust-analyzer.command = "${rust-analyzer-unwrapped}/bin/rust-analyzer";
              rust-analyzer.config = {
                "inlayHints.bindingModeHints.enable" = true;
                "inlayHints.closingBraceHints.minLines" = 10;
                "inlayHints.closureReturnTypeHints.enable" = "with_block";
                "inlayHints.discrimiinantHints.enable" = "skip_trivial";
                "inlayHints.typeHints.hideClosureInitialization" = false;
              };

              yaml-language-server = {
                command = "${yaml-language-server}/bin/yaml-language-server";
                args = [ "--stdio" ];
                config.yaml.schemas = {
                  "https://json.schemastore.org/github-action.json" = [
                    "action.yml"
                    "action.yaml"
                  ];
                };
              };
            };

          #https://github.com/helix-editor/helix/blob/master/languages.toml
          language = [
            # {
            #   name = "json5";
            #   scope = "*";
            #   # shebangs = ["json"];
            # }
            {
              name = "javascript";
              formatter = {
                command = "prettier";
                args = [
                  "--parser"
                  "typescript"
                ];
              };
              language-servers = [
                "typescript-language-server"
                "eslint"
              ];
              auto-format = true;
            }
            {
              name = "typescript";
              formatter = {
                command = "prettier";
                args = [
                  "--parser"
                  "typescript"
                ];
              };
              language-servers = [
                "typescript-language-server"
                "eslint"
              ];
              auto-format = true;
            }
            {
              name = "svelte";
              formatter = {
                command = "prettier";
                args = [
                  "--plugin"
                  "prettier-plugin-svelte"
                ];
              };
              language-servers = [
                "tailwindcss-ls"
                "svelteserver"
                "eslint"
              ];
              auto-format = true;
            }
            {
              name = "nix";
              auto-format = true;
              formatter = {
                command = "nixfmt"; # "nixpkgs-fmt";
              };
              language-servers = [
                "nixd"
                "nil"
                "copilot"
              ];
            }
            {
              name = "nim";
              auto-format = true;
              formatter = {
                command = "nimpretty";
              };
              # language-servers = [ "nimlsp" "nimlangserver" ];
            }
            {
              name = "python";
              language-servers = [
                "pylsp"
                "pyright"
              ];
              formatter = {
                command = "black";
                args = [
                  "--quiet"
                  "-"
                ];
              };
              auto-format = true;
            }
            {
              name = "rust";
              auto-format = true;
              language-servers = [
                "rust-analyzer"
                "copilot"
              ];
            }
            {
              name = "markdown";
              auto-format = true;
              formatter = {
                command = "dprint";
                args = [
                  "fmt"
                  "--stdin"
                  "md"
                ];
              };
              language-servers = [
                "marksman"
              ];
            }
            {
              name = "yaml";
              scope = "source.yaml";
              file-types = [
                "yml"
                "yaml"
              ];
              auto-format = true;
              language-servers = [ "yaml-language-server" ];
            }
          ];
        };
      };
    }) config.my.users;
  };
}
