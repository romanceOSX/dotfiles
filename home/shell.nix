{ pkgs, lib, config, isWSL ? false, ... }:
{
  # ---------------------------------------------------------------------------
  # Environment (translated from .commonrc "Environment" + "ls colors")
  # ---------------------------------------------------------------------------
  home.sessionVariables = {
    CLICOLOR = "1";
    COLORTERM = "truecolor";
    EDITOR = "nvim";
    VISUAL = "nvim";
    LSCOLORS = "FxGxCxDxFxegedabagacad";
    # Pastel-rainbow LS_COLORS — same palette as rainbow-prompt / yazi.
    # fi (default file) mirrors eza's `normal` #C8C0C5 so dust — which themes
    # filenames purely via LS_COLORS — matches eza/yazi for both files and dirs.
    LS_COLORS = lib.concatStringsSep ":" [
      "fi=38;2;200;192;197"
      "di=1;38;2;148;247;228"
      "ln=1;38;2;148;247;228"
      "ex=1;38;2;163;220;191"
      "so=1;38;2;207;148;247"
      "pi=38;2;246;207;148"
      "bd=38;2;158;196;254"
      "cd=38;2;207;148;247"
      "su=1;38;2;250;158;196"
      "sg=38;2;250;158;196"
      "tw=1;38;2;246;207;148"
      "ow=38;2;246;207;148"
    ];
  };

  # ~/.local/bin (scripts) + TeX on macOS. scripts.nix also adds ~/.local/bin,
  # but listing it here keeps the intent local to env config.
  home.sessionPath =
    [ "${config.home.homeDirectory}/.local/bin" ]
    ++ lib.optionals pkgs.stdenv.isDarwin [ "/Library/TeX/texbin" ];

  # ---------------------------------------------------------------------------
  # zsh (translated from .commonrc + .zshrc)
  # ---------------------------------------------------------------------------
  programs.zsh = {
    enable = true;

    # --- WSL <-> Windows interop for ssh sessions ---------------------------
    # WSL only appends the Windows PATH (and exports WSL_INTEROP) for shells it
    # starts via `/init` (i.e. `wsl.exe`). A standalone sshd skips that, so
    # `cmd.exe`/`powershell.exe` -- and the `cmd`/`cansniff` aliases below --
    # are not found by name over ssh, even though binfmt interop still launches
    # them by full path. Put this in .zshenv (envExtra) so it applies to
    # non-interactive `ssh host <cmd>` too. Guarded at runtime on WSL_INTEROP
    # being unset (a normal wsl.exe login is left untouched) and on cmd.exe
    # existing (no-op on non-WSL hosts).
    envExtra = lib.optionalString isWSL ''
      if [[ -z "$WSL_INTEROP" && -x /mnt/c/Windows/System32/cmd.exe ]]; then
        typeset -U path
        path+=(
          /mnt/c/Windows/System32
          /mnt/c/Windows
          /mnt/c/Windows/System32/WindowsPowerShell/v1.0
        )
        export PATH
      fi
    '';
    dotDir = "${config.xdg.configHome}/zsh";
    enableCompletion = true; # runs compinit (needed by fzf-tab)
    defaultKeymap = "viins"; # `set -o vi`, start in insert mode

    # LINUX ONLY: if the login shell is system zsh, re-exec into nix's zsh so
    # nix-built modules (fzf-tab) load against the matching glibc. The guard uses
    # /proc, which doesn't exist on macOS — so on darwin this whole block is
    # omitted (otherwise the guard is always true and login shells exec forever).
    # macOS doesn't need it: system zsh sources HM's ~/.zshrc fine, no glibc.
    profileExtra = lib.optionalString pkgs.stdenv.isLinux ''
      if [[ "$(realpath /proc/$$/exe 2>/dev/null)" != */nix/store/* ]]; then
        NIX_ZSH="$HOME/.nix-profile/bin/zsh"
        if [[ -x "$NIX_ZSH" ]]; then
          export SHELL="$NIX_ZSH"
          exec "$NIX_ZSH" -l
        fi
      fi
    '';

    # Remove broken system completions (e.g. Docker Desktop on WSL when not running)
    completionInit = ''
      fpath=( ''${fpath:#/usr/share/zsh/vendor-completions} )
      autoload -U compinit && compinit
    '';

    history = {
      path = "${config.home.homeDirectory}/.history";
      size = 100000;
      save = 100000;
      share = true; # SHARE_HISTORY
      ignoreDups = true; # HIST_IGNORE_DUPS
      ignoreAllDups = true; # HIST_IGNORE_ALL_DUPS
    };

    shellAliases = {
      "%" = " ";

      # --- modern CLI replacements (tools installed in packages.nix) ---
      # eza for ls/listing/tree; --icons=auto only decorates a tty.
      ls = "eza --color=auto --icons=auto --group-directories-first";
      l = "eza -al --color=auto --icons=auto --group-directories-first"; # all + long
      ll = "eza -l --color=auto --icons=auto --group-directories-first";
      la = "eza -a --color=auto --icons=auto --group-directories-first";
      tree = "eza --tree --icons=auto --group-directories-first";
      cat = "bat --paging=never"; # cat-like; bat auto-plain when piped
      du = "dust";
      df = "duf";
      ps = "procs";
      # top intentionally NOT aliased — keep the system default; run `btop` explicitly.
      watch = "viddy";
      diff = "delta";
      which = "command -v";
      # NOTE: find/grep/man are intentionally NOT aliased to fd/rg/tldr — their
      # CLIs differ enough that aliasing breaks flags and pipelines. Use the new
      # tools by name (`fd`, `rg`, `tldr`); `cd` is replaced by zoxide below.
      tldrf = "head -n 2 $HOME/Library/Caches/tealdeer/pages/*/*/*.md | grep -E '^==|^>' | paste -d ' ' - - | sed 's/# //g' | fzf --preview 'tldr {1} --color=always'";
      how = "head -n 2 $HOME/Library/Caches/tealdeer/pages/*/*/*.md | grep -E '^==|^>' | paste -d ' ' - - | sed 's/# //g' | fzf --preview 'tldr {1} --color=always'";

      toks = "tokscale";
      lg = "lazygit";
      g = "git";
      pip = "pip3";
      python = "python3";
      "clang++" = "clang++ -std=c++20";
      vim = "nvim"; # neovim is installed as a plain package (see packages.nix)
      vi = "nvim";
      cansniff = "cmd.exe /c cansniff.exe";
      cmd = "cmd.exe /c";
      posh = "powershell.exe -NoProfile -Command";
      clip = "pbcopy"; # pipe stdout to clipboard; overridden to wl-copy on Linux
    } // lib.optionalAttrs pkgs.stdenv.isLinux {
      open = "xdg-open"; # macOS has a native `open`
      clip = "wl-copy";
      tldrf = "head -n 2 $HOME/.cache/tealdeer/pages/*/*/*.md | grep -E '^==|^>' | paste -d ' ' - - | sed 's/# //g' | fzf --preview 'tldr {1} --color=always'";
      how = "head -n 2 $HOME/.cache/tealdeer/pages/*/*/*.md | grep -E '^==|^>' | paste -d ' ' - - | sed 's/# //g' | fzf --preview 'tldr {1} --color=always'";
    };

    # fzf-tab — fuzzy Tab completion. Sourced after compinit by HM.
    plugins = [
      {
        name = "fzf-tab";
        src = pkgs.zsh-fzf-tab;
        file = "share/fzf-tab/fzf-tab.plugin.zsh";
      }
    ];

    initContent = ''
'' + lib.optionalString pkgs.stdenv.isDarwin ''
      # --- keep nix's bins ahead of macOS system bins (PATH ordering) ---
      # macOS /etc/zprofile runs path_helper, which rebuilds PATH with the
      # /etc/paths system dirs FIRST and the inherited entries (incl.
      # ~/.nix-profile/bin) appended. nix-daemon.sh would normally re-prepend the
      # nix dirs, but in nested/inherited shells its __ETC_PROFILE_NIX_SOURCED
      # guard makes it return early — so nix never gets back in front and
      # /usr/bin/python3 (etc.) shadows the nix install. Re-assert the nix dirs at
      # the front here (~/.zshrc runs after path_helper, and isn't guarded).
      typeset -U path
      path=( "$HOME/.nix-profile/bin" /nix/var/nix/profiles/default/bin $path )
      export PATH
'' + ''
      # --- eza pastel-rainbow theme ---
      # eza reads theme.yml (deployed by programs.nix) from EZA_CONFIG_DIR; this
      # build does NOT auto-discover ~/.config/eza. Set here (interactive init)
      # rather than home.sessionVariables so EVERY shell gets it — including tmux
      # panes that inherit a frozen server env from before the var existed.
      # Without it eza falls back to harsh default ANSI colours.
      export EZA_CONFIG_DIR="${config.xdg.configHome}/eza"

      # --- prompt cosmetics (from .zshrc) ---
      PROMPT_SP=""
      unsetopt PROMPT_CR

      # --- vi insert-mode emacs keybindings (from .commonrc) ---
      bindkey -M viins '^A' beginning-of-line
      bindkey -M viins '^E' end-of-line
      bindkey -M viins '^K' kill-line
      bindkey -M viins '^U' backward-kill-line
      bindkey -M viins '^W' backward-kill-word
      bindkey -M viins '^L' clear-screen
      bindkey -M viins '^P' up-line-or-history
      bindkey -M viins '^N' down-line-or-history
      bindkey -M viins '^R' fzf-history-widget
      bindkey -M viins '^B' backward-char
      bindkey -M viins '^F' forward-char

      # --- vi-mode yank to the system clipboard (from .zshrc) ---
      function vi-yank-clip {
          zle vi-yank
          if command -v pbcopy >/dev/null 2>&1; then
              echo "$CUTBUFFER" | pbcopy
          elif command -v xclip >/dev/null 2>&1; then
              echo "$CUTBUFFER" | xclip -selection clipboard
          elif command -v wl-copy >/dev/null 2>&1; then
              echo "$CUTBUFFER" | wl-copy
          fi
      }
      zle -N vi-yank-clip
      bindkey -M vicmd 'y' vi-yank-clip

      # --- edit the command line in $EDITOR (^G) ---
      # edit-command-line resets CURSOR to 0 on return, dumping you at the start
      # of the prompt. Wrap it to land the cursor on the last written character.
      autoload -Uz edit-command-line
      zle -N edit-command-line
      function _edit-command-line-eol() {
        zle edit-command-line
        CURSOR=''${#BUFFER}
      }
      zle -N _edit-command-line-eol
      bindkey '^G' _edit-command-line-eol

      # --- page command output (taskwarrior #13) ---------------------------
      # Themed pager shared by the `L` global alias and the ^O widget below.
      # Swap bat -> less here (one place) to change the pager everywhere.
      function _page() { bat --paging=always "$@"; }

      # Global alias: append `L` to any command to page its combined output.
      #   ls -la L            -> ls -la 2>&1 | _page
      #   git log L           -> git log 2>&1 | _page
      # `2>&1` folds stderr in so compiler/make spew is paged too. Like all zsh
      # global aliases, `L` expands anywhere on the line, so don't use a bare
      # `L` as a normal argument (the single-letter global-alias footgun).
      alias -g L='2>&1 | _page'

      # ^O — re-run the PREVIOUS command, paging its combined output. Re-executes
      # the command (side effects!), so best for read-only commands (ls, git
      # log, cat...). The brace group captures the whole pipeline's stdout+stderr.
      function _page-last-output() {
        local last=$(fc -ln -1)
        [[ -n $last ]] || return
        BUFFER="{ $last; } 2>&1 | _page"
        zle accept-line
      }
      zle -N _page-last-output
      bindkey -M viins '^O' _page-last-output


      # --- clipboard history daemon auto-start (Linux/Wayland only) ---
      # macOS: launchd agent (see launchd.agents.clipd below) handles this.
      # Linux: start clipd when Wayland is available (WSLg sets WAYLAND_DISPLAY).
      function _clipd-ensure() {
        [[ -n "''${WAYLAND_DISPLAY:-}" ]] || return
        local pidfile="''${XDG_DATA_HOME:-$HOME/.local/share}/cliph/daemon.pid"
        { [[ -f "$pidfile" ]] && kill -0 "$(<"$pidfile")" 2>/dev/null; } && return
        command -v clipd >/dev/null 2>&1 && clipd &>/dev/null &!
      }
      _clipd-ensure
      unfunction _clipd-ensure

      # --- ^Y — clipboard history picker (cliph) ---
      # Opens the fzf picker; inserts selected text into the command line.
      function _cliph-widget() {
        local result
        result=$(CLIPH_PRINT=1 cliph 2>/dev/null) || return
        [[ -z "$result" ]] && return
        LBUFFER+="$result"
        zle redisplay
      }
      zle -N _cliph-widget
      bindkey -M viins '^Y' _cliph-widget


      # --- run-help: drop zsh's default `run-help=man` alias (the last alias
      # still pointing at a legacy util) for the smarter autoloaded function,
      # which understands builtins, aliases and git subcommands, not just man. ---
      unalias run-help 2>/dev/null
      autoload -Uz run-help

      # --- fzf-tab tuning (from .commonrc) ---
      zstyle ':completion:*' menu no
      zstyle ':fzf-tab:*' fzf-flags --bind=ctrl-j:down,ctrl-k:up,ctrl-n:down,ctrl-p:up,ctrl-y:accept,tab:accept

      # --- yazi: cd into the last dir on quit (the `y` wrapper from .commonrc) ---
      function y() {
          local tmp cwd
          tmp="$(mktemp -t "yazi-cwd.XXXXXX")"
          command yazi "$@" --cwd-file="$tmp"
          IFS= read -r -d "" cwd < "$tmp"
          [ -n "$cwd" ] && [ "$cwd" != "$PWD" ] && [ -d "$cwd" ] && builtin cd -- "$cwd"
          command rm -f -- "$tmp"
      }

      # --- daemons / ports: list running services (from .commonrc) ---
      function daemons() {
          if [ "$(uname)" = "Darwin" ]; then
              echo "== launchd (user) =="
              launchctl list | awk 'NR==1 || $1 != "-"'
              echo
              echo "== launchd (system) =="
              sudo launchctl list 2>/dev/null | awk 'NR==1 || $1 != "-"'
          elif command -v systemctl >/dev/null 2>&1; then
              echo "== systemd (system) =="
              systemctl list-units --type=service --state=running --no-pager
              echo
              echo "== systemd (user) =="
              systemctl --user list-units --type=service --state=running --no-pager 2>/dev/null
          else
              echo "No systemd/launchd found; falling back to listening network services:"
              ports
          fi
      }

      function ports() {
          if [ "$(uname)" = "Darwin" ]; then
              sudo lsof -i -P -n | grep LISTEN
          elif command -v ss >/dev/null 2>&1; then
              ss -tulpn
          else
              sudo lsof -i -P -n | grep LISTEN
          fi
      }
    '';
  };

  # ---------------------------------------------------------------------------
  # fzf — replaces the homebrew ~/.fzf.zsh sourcing in .commonrc
  # ---------------------------------------------------------------------------
  programs.fzf = {
    enable = true;
    enableZshIntegration = true; # ^R / ^T / ALT-C + ** completion
    # Unified navigation for EVERY fzf picker (FZF_DEFAULT_OPTS; inherited by
    # fzf-tab, zoxide `cdi`, tmux popups, and all ad-hoc fzf invocations).
    # See docs/keybindings.md for the full reference.
    # NOTE: tab:accept removes Tab's multi-select toggle — fine for all current
    # pickers (none use multi-select), but a future `-m` picker would need its
    # own FZF_*_OPTS to rebind Tab back to toggle.
    defaultOptions = [
      "--bind=ctrl-j:down,ctrl-k:up,ctrl-n:down,ctrl-p:up,ctrl-y:accept,tab:accept"
    ];
  };

  # ---------------------------------------------------------------------------
  # zoxide — smart `cd`. `--cmd cd` shadows the builtin so `cd` learns/jumps;
  # `cdi` gives the interactive picker. Plain `cd <path>` still works as normal.
  # ---------------------------------------------------------------------------
  programs.zoxide = {
    enable = true;
    enableZshIntegration = true;
    options = [ "--cmd cd" ];
  };

  # ---------------------------------------------------------------------------
  # starship — reads your existing starship.toml verbatim
  # ---------------------------------------------------------------------------
  programs.starship = {
    enable = true;
    enableZshIntegration = true;
    settings = builtins.fromTOML (builtins.readFile ./starship.toml);
  };

  # ---------------------------------------------------------------------------
  # clipd launchd agent (macOS only) — polls pbpaste and stores clipboard
  # history under ~/.local/share/cliph/. KeepAlive restarts on crash/logout.
  # ---------------------------------------------------------------------------
  launchd.agents.clipd = lib.mkIf pkgs.stdenv.isDarwin {
    enable = true;
    config = {
      ProgramArguments = [ "${config.home.homeDirectory}/.local/bin/clipd" ];
      RunAtLoad = true;
      KeepAlive = true;
    };
  };
}
