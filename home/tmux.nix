{ pkgs, config, ... }:
let
  resurrectDir = "${config.xdg.dataHome}/tmux/resurrect";
  keepLastSnapshots = 10;
  # Shared fzf navigation contract — see docs/keybindings.md. tmux popups run
  # fzf via `sh -c`, which doesn't reliably inherit FZF_DEFAULT_OPTS from the
  # (possibly frozen) tmux server env, so every popup picker passes it inline.
  fzfNav = "--bind=ctrl-j:down,ctrl-k:up,ctrl-n:down,ctrl-p:up,ctrl-y:accept,tab:accept";
in
{
  # Ship the sessionizer default/example to ~/.config/tmux/sessionizer.toml.example
  # (read-only, in-store). The <prefix>f menu falls back to it when no custom
  # config exists. To customize, copy it to ~/.config/tmux/sessionizer.toml
  # (machine-local, not nix-managed) — the menu prefers that copy and reads it
  # fresh on every keypress, so edits are live with no switch / no tmux reload.
  xdg.configFile."tmux/sessionizer.toml.example".source = ./tmux-sessionizer.toml.example;
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

    # NOTE: tmux-continuum is intentionally NOT in the `plugins` list. HM emits the
    # plugin `run-shell` lines BEFORE extraConfig, and tmux-nova's load resets
    # `status-right` (nova.sh: `set-option -g status-right ""`) — which would wipe
    # continuum's `#(continuum_save.sh)` auto-save hook. continuum is instead loaded
    # at the very END of extraConfig, so it runs after nova and after its
    # @continuum-* options are set (continuum reads them at load time).
    plugins = with pkgs.tmuxPlugins; [
      {
        plugin = resurrect;
        # Move resurrect's manual save/restore OFF the Ctrl keys. The prefix is
        # C-a, so holding Ctrl a few ms too long while pressing `s` (session
        # list) or `r` (reload) sends C-s / C-r — resurrect's DEFAULT save and
        # restore keys — silently firing a save/restore. The slip is timing- and
        # terminal-dependent, so it shows up intermittently on WSL but not macOS.
        # Rebinding to `prefix S` / `prefix R` frees C-s and C-r (which extraConfig
        # then repurposes to the intended actions). This MUST be set here, before
        # resurrect.tmux runs: resurrect reads these at bind time, and HM emits a
        # plugin's run-shell BEFORE extraConfig (where @resurrect-dir etc. live).
        extraConfig = ''
          set -g @resurrect-save 'S'
          set -g @resurrect-restore 'R'
        '';
      }
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
      # New windows/splits route through tmux-remote-shell so that, inside a
      # remote (@ssh_host) session, a new shell re-enters the SAME host over ssh
      # instead of dropping back to a local shell. In a local session it behaves
      # exactly like the stock new-window / split-window (same start dir).
      bind - run-shell "~/.local/bin/tmux-remote-shell vsplit"
      bind | run-shell "~/.local/bin/tmux-remote-shell hsplit"
      bind c run-shell "~/.local/bin/tmux-remote-shell window"
      unbind '"'
      unbind %

      bind h select-pane -L
      bind j select-pane -D
      bind k select-pane -U
      bind l select-pane -R

      # <prefix>L jumps to the last session this client was attached to.
      # (The vim-style pane *resize* binds that used to live on H/J/K/L are gone;
      # resize via mouse drag instead.)
      bind L switch-client -l

      set-option -g pane-active-border-style "fg=#C58EA7,bg=default"
      set-option -g pane-border-style "fg=#2F2B30,bg=default"

      # --- Windows ---
      bind w display-popup -E "tmux list-windows -F '#{window_index}: #{window_name}' | fzf --reverse ${fzfNav} | cut -d: -f1 | xargs tmux select-window -t"
      bind Tab last-window
      bind -r n next-window
      bind -r p previous-window

      # --- Sessions ---
      # <prefix>f opens a session-finder menu built from
      # ~/.config/tmux/sessionizer.toml (key → dirs mappings).
      # Navigate with j/k or arrows; press an entry key to jump directly.
      bind f run-shell "~/.local/bin/tmux-sessionizer-menu"

      # Pastel styling for all display-menu popups (matches the nova status bar).
      set -g menu-style "bg=#191719,fg=#7E7480"
      set -g menu-selected-style "bg=#C58EA7,fg=#191719"
      set -g menu-border-style "fg=#2F2B30"
      bind N command-prompt -p "Session name:" "new-session -s '%%'"
      bind -r ( switch-client -p
      bind -r ) switch-client -n
      bind X kill-session
      set-hook -g after-new-session 'resize-pane -D 1'

      # aoe (agent-of-empires) creates its agent sessions with `window-size
      # manual` + a fixed `default-size` (sized to its embedded live-mode view),
      # so attaching a full-screen client doesn't resize the window and you get
      # whitespace around the agent. For aoe_* sessions only, restore auto-sizing
      # (latest = follow the active client) and force an immediate resize on
      # attach. Other sessions are untouched.
      set-hook -g client-attached 'if -F "#{m:aoe_*,#{session_name}}" "set -w window-size latest ; resize-window -A"'

      # --- Status bar ---
      set -g status on

      # --- Utilities ---
      bind r source-file ${config.xdg.configHome}/tmux/tmux.conf \; display-message "Config reloaded!"
      # resurrect's manual save/restore now live on `prefix S` / `prefix R` (set
      # before the plugin loads, above). That frees C-s / C-r, which were firing
      # accidental save/restore when Ctrl lingered from the C-a prefix into `s` /
      # `r`. Repurpose the freed Ctrl keys to the action the user actually meant,
      # so even a fumbled `prefix C-s` opens the session list (and C-r reloads).
      bind C-s choose-tree -Zs
      bind C-r source-file ${config.xdg.configHome}/tmux/tmux.conf \; display-message "Config reloaded!"
      bind ? display-popup -E -w 80% -h 60% "tmux list-keys | bat -l bash --color=always --style=plain | fzf --ansi ${fzfNav}"
      bind t display-popup -E -w 30% -h 40% "tmux-launcher"
      bind T display-popup -E -w 90% -h 90% "taskwarrior-tui"
      bind C-l send-keys 'clear' Enter
      # <prefix>i: a config/continuum/server info window (tmux-conf-info reads the
      # snapshot dir + retention cap so it stays in sync with the prune below).
      bind i display-popup -E -w 80% -h 80% "tmux-conf-info '${resurrectDir}' '${toString keepLastSnapshots}'"

      # --- resurrect / continuum (options consumed by the nix-managed plugins) ---
      # Pin the save dir to the XDG path. Without this, this resurrect build
      # falls back to ~/.tmux/resurrect, which diverges from the prune below
      # (so old saves accumulate unbounded). Keep both pointing here.
      set -g @resurrect-dir "${resurrectDir}"
      set -g @continuum-restore 'on'
      set -g @continuum-save-interval '5'

      # Don't restore a blank session: bring back the on-screen pane text and
      # re-launch the programs that were running.
      #   - capture-pane-contents 'on' saves/replays each pane's visible buffer,
      #     so restored panes show their previous output instead of an empty shell.
      #   - @resurrect-processes re-launches programs. resurrect ALREADY restores
      #     a default list (vi/vim/nvim/emacs/man/less/more/tail/top/htop/...);
      #     entries here are ADDED to it. A leading `~` relaxes name matching so
      #     the full binary path saved in the snapshot still matches.
      set -g @resurrect-capture-pane-contents 'on'
      set -g @resurrect-processes 'ssh "~lazygit" "~btop" "~yazi" "~taskwarrior-tui" "~claude" "~copilot"'

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

      # --- continuum: load LAST (see the note above the plugins list) ---
      # Loading here — after tmux-nova has built status-right and after the
      # @continuum-restore / @continuum-save-interval options above — is what
      # makes the periodic auto-save actually fire and auto-restore on start
      # honour the settings. continuum prepends its `#(continuum_save.sh)` hook
      # to the existing status-right, so it coexists with nova's time segment.
      run-shell ${pkgs.tmuxPlugins.continuum}/share/tmux-plugins/continuum/continuum.tmux
      # Guard: continuum skips adding its save hook when it thinks another tmux
      # server is running. This can happen if resurrect's tmux_spinner.sh orphans
      # a "tmux display-message" child that inflates the process count. The guard
      # script re-adds the hook if continuum's check blocked it. Idempotent.
      run-shell "~/.local/bin/tmux-continuum-ensure-hook '${pkgs.tmuxPlugins.continuum}/share/tmux-plugins/continuum/scripts/continuum_save.sh'"

      # --- cap the number of retained snapshots ---
      # continuum saves via a `#(continuum_save.sh)` interpolation it prepends to
      # status-right (re-run every status-interval). Append our prune right after
      # so each save is immediately followed by a cleanup that keeps only the
      # newest ${toString keepLastSnapshots} snapshots — bounding the dir even
      # during a long, never-detached session. The script prints nothing, so it
      # adds no visible text to the status bar.
      set -ga status-right "#(~/.local/bin/tmux-resurrect-prune '${resurrectDir}' '${toString keepLastSnapshots}')"
    '';
  };
}
