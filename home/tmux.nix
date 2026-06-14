{ pkgs, config, ... }:
{
  # ---------------------------------------------------------------------------
  # tmux (translated from .tmux.conf)
  #
  # The tpack/@plugin management is replaced by nix-managed plugins below.
  # `sensibleOnTop` (default true) pulls in tmux-sensible, so it's not listed.
  # Everything that isn't a plain option lives in extraConfig.
  # ---------------------------------------------------------------------------
  programs.tmux = {
    enable = true;
    prefix = "C-a";
    baseIndex = 1;
    escapeTime = 0;
    mouse = true;
    keyMode = "vi";
    terminal = "tmux-256color";
    historyLimit = 50000;

    plugins = with pkgs.tmuxPlugins; [
      resurrect
      continuum
      yank
      tmux-fzf
      tmux-nova
    ];

    extraConfig = ''
      # --- General ---
      # `v` starts a selection. `y` is intentionally NOT rebound here: the
      # tmux-yank plugin binds it to copy to the system clipboard (pbcopy /
      # xclip / wl-copy, auto-detected). Overriding it with a bare
      # copy-pipe-and-cancel would only fill tmux's internal buffer — under HM
      # extraConfig is applied *after* plugins, so the override would win and
      # break clipboard copy (it doesn't under TPM, where plugins load last).
      bind-key -T copy-mode-vi v send-keys -X begin-selection
      # Also let tmux push copies to the terminal's clipboard via OSC52, so
      # Enter / mouse-drag copies reach the system clipboard too.
      set -g set-clipboard on
      set -g detach-on-destroy off     # Stay in tmux when session closes
      set -g renumber-windows on       # No gaps after closing windows
      set -g repeat-time 700

      if-shell "uname | grep -q MINGW" "set -g default-shell 'C:/Program Files/Git/bin/bash.exe'"
      set-option -sa terminal-overrides ',xterm-256color:RGB'
      set -as terminal-overrides ',*:Smulx=\E[4::%p1%dm'
      set -as terminal-overrides ',*:Setulc=\E[58::2::%p1%{65536}%/%d::%p1%{256}%/%{255}%&%d::%p1%{255}%&%d%;m'

      # --- Panes ---
      bind - split-window -v -c "#{pane_current_path}"
      bind | split-window -h -c "#{pane_current_path}"
      bind c new-window -c "#{pane_current_path}"
      unbind '"'
      unbind %

      bind h select-pane -L
      bind j select-pane -D
      bind k select-pane -U
      bind l select-pane -R

      bind -r H resize-pane -L 5
      bind -r J resize-pane -D 5
      bind -r K resize-pane -U 5
      bind -r L resize-pane -R 5

      set-option -g pane-active-border-style "fg=#C58EA7,bg=default"
      set-option -g pane-border-style "fg=#2F2B30,bg=default"

      # --- Windows ---
      bind w display-popup -E "tmux list-windows -F '#{window_index}: #{window_name}' | fzf --reverse | cut -d: -f1 | xargs tmux select-window -t"
      bind Tab last-window
      bind -r n next-window
      bind -r p previous-window

      # --- Sessions ---
      # <prefix>f opens a which-key-style menu (native display-menu) listing the
      # session-finder keys and their actions, so the shortcuts are discoverable.
      # Each entry fzf-browses a folder via tmux-sessionizer in a popup (which
      # gives fzf a tty; -p makes the script follow symlinks like ~/notes).
      bind f display-menu -T "#[align=centre,fg=#C58EA7]󰍉 sessionizer " -x C -y C \
        "git    (~/git)"          g "display-popup -E 'tmux-sessionizer -p ~/git'" \
        "git    (~/git)"          p "display-popup -E 'tmux-sessionizer -p ~/git'" \
        "notes  (~/notes)"        n "display-popup -E 'tmux-sessionizer -p ~/notes'" \
        "home   (~)"              h "display-popup -E 'tmux-sessionizer -p ~'" \
        "" \
        "all    (git + home + notes)" f "display-popup -E 'tmux-sessionizer'"

      # Pastel styling for all display-menu popups (matches the nova status bar).
      set -g menu-style "bg=#191719,fg=#7E7480"
      set -g menu-selected-style "bg=#C58EA7,fg=#191719"
      set -g menu-border-style "fg=#2F2B30"
      bind N command-prompt -p "Session name:" "new-session -s '%%'"
      bind -r ( switch-client -p
      bind -r ) switch-client -n
      bind X kill-session
      set-hook -g after-new-session 'resize-pane -D 1'

      # --- Status bar ---
      set -g status on

      # --- Utilities ---
      bind r source-file ${config.xdg.configHome}/tmux/tmux.conf \; display-message "Config reloaded!"
      bind ? display-popup -E -w 80% -h 60% "tmux list-keys | bat -l bash --color=always --style=plain | fzf --ansi"
      bind t display-popup -E -w 30% -h 40% "tmux-launcher"
      bind C-l send-keys 'clear' Enter

      # --- resurrect / continuum (options consumed by the nix-managed plugins) ---
      # Pin the save dir to the XDG path. Without this, this resurrect build
      # falls back to ~/.tmux/resurrect, which diverges from the cleanup hook
      # below (so old saves accumulate unbounded). Keep both pointing here.
      set -g @resurrect-dir "${config.xdg.dataHome}/tmux/resurrect"
      set-hook -g client-detached "run 'ls -t ${config.xdg.dataHome}/tmux/resurrect/tmux_resurrect_*.txt 2>/dev/null | tail -n +11 | xargs rm -f'"
      set -g @continuum-restore 'on'
      set -g @continuum-save-interval '5'

      # --- sessionx (options harmless if the plugin isn't installed) ---
      set -g @sessionx-bind 'o'
      set -g @sessionx-fzf-builtin-tmux 'on'

      # --- nova status bar: per-letter muted pastel gradient via tmux-rainbow ---
      set -g @nova-nerdfonts false
      set -g @nova-pane " #I:#W#{?window_zoomed_flag, 󰍉,} "
      set -g @nova-pane-justify "left"
      set -g @nova-pane-active-border-style "#C58EA7"
      set -g @nova-pane-border-style "#2F2B30"
      set -g @nova-status-style-bg "#191719"
      set -g @nova-status-style-fg "#7E7480"
      set -g @nova-status-style-active-bg "#C58EA7"
      set -g @nova-status-style-active-fg "#191719"
      set -g @nova-segment-session "#(~/.local/bin/tmux-rainbow '#{session_name}')"
      set -g @nova-segment-session-colors "#191719 #7E7480"
      set -g @nova-segment-time "#(~/.local/bin/tmux-rainbow '%Y-%m-%d %H:%M')"
      set -g @nova-segment-time-colors "#191719 #7E7480"
      set -g @nova-segments-0-left "session"
      set -g @nova-segments-0-right "time"
    '';
  };
}
