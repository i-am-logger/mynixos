{ config, lib, pkgs, ... }:

with lib;

{
  # Option is declared in flake.nix
  config = {
    home-manager.users = mapAttrs
      (name: userCfg:
        let
          termCfg = userCfg.terminal or { };
          isTmux = (termCfg.multiplexer or "zellij") == "tmux";
        in
        mkIf isTmux {
          programs.tmux = {
            aggressiveResize = true;
            baseIndex = 1;
            enable = true;
            clock24 = true;
            plugins = with pkgs; [
              tmuxPlugins.fzf-tmux-url
              tmuxPlugins.better-mouse-mode
              tmuxPlugins.sensible
            ];
            customPaneNavigationAndResize = true;
            escapeTime = 0;
            historyLimit = 50000;
            extraConfig = ''
              set-option -g default-command usr/bin/env bash
              set -g status-justify "left"
              set -g status "on"
              set -g status-left-style none
              set -g message-command-style "fg=colour146,bg=colour60"
              set -g status-right-style "none"
              set -g pane-active-border-style "fg=colour117"
              set -g status-style bg=colour60
              set -g message-style "fg=colour146,bg=colour60"
              set -g pane-border-style "fg=colour60"
              set -g status-right-length "100"
              set -g status-left-length "100"
              setw -g window-status-activity-style "none"
              setw -g window-status-separator ""
              setw -g window-status-style "none,fg=colour60,bg=colour60"
              set -g status-left "#[fg=colour232,bg=colour117] #{?client_prefix,#[fg=white],} #S #[fg=colour117,bg=colour60,nobold,nounderscore,noitalics]"
              set -g status-right "#[fg=colour60,bg=colour60,nobold,nounderscore,noitalics]#[fg=colour146,bg=colour60] %Y-%m-%d  %H:%M #[fg=colour117,bg=colour60,nobold,nounderscore,noitalics]#[fg=colour232,bg=colour117] #h "
              setw -g window-status-format "#[fg=colour60,bg=colour60] #I #[fg=colour60,bg=colour60] #W "
              setw -g window-status-current-format "#[fg=colour60,bg=colour60,nobold,nounderscore,noitalics]#[fg=colour146,bg=colour60] #I #[fg=colour146,bg=colour60] #W #[fg=colour60,bg=colour60,nobold,nounderscore,noitalics]"
              set -g mouse on
              bind v split-window -h -c '#{pane_current_path}'
              bind s split-window -v -c '#{pane_current_path}'
              bind c new-window -c '#{pane_current_path}'
              bind-key R source-file $XDG_CONFIG_HOME/tmux/tmux.conf \; display-message "$XDG_CONFIG_HOME/tmux/tmux.conf reloaded"
              bind L switch-client -l
              bind J display-popup -E "\
              tmux list-panes -a -F '#{?session_attached,,#S:#I.#P}' |\
              sed '/^$/d' |\
              fzf --reverse --header join-pane --preview 'tmux capture-pane -pt {}'  |\
              xargs tmux join-pane -v -s"
              set-option -g renumber-windows on
            '';
          };
        })
      (config.my.users or {});
  };
}