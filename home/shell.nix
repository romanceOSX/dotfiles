{ pkgs, lib, config, ... }:
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
    LS_COLORS = lib.concatStringsSep ":" [
      "di=1;38;2;197;142;167"
      "ln=1;38;2;148;247;228"
      "ex=1;38;2;180;250;158"
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
      l = "ls -alh";
      ls = "ls --color=auto"; # nix coreutils ls is GNU, honours LS_COLORS
      lg = "lazygit";
      g = "git";
      diff = "diff -u";
      pip = "pip3";
      python = "python3";
      "clang++" = "clang++ -std=c++20";
      # `vim` -> `nvim` is provided by programs.neovim.vimAlias
      cansniff = "cmd.exe /c cansniff.exe";
      cmd = "cmd.exe /c";
    } // lib.optionalAttrs pkgs.stdenv.isLinux {
      open = "xdg-open"; # macOS has a native `open`
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

      # --- edit the command line in $EDITOR (^X^E) ---
      autoload -Uz edit-command-line
      zle -N edit-command-line
      bindkey '^X^E' edit-command-line

      # --- fzf-tab tuning (from .commonrc) ---
      zstyle ':completion:*' menu no
      zstyle ':fzf-tab:*' fzf-flags --bind=tab:accept

      # --- yazi: cd into the last dir on quit (the `y` wrapper from .commonrc) ---
      function y() {
          local tmp cwd
          tmp="$(mktemp -t "yazi-cwd.XXXXXX")"
          command yazi "$@" --cwd-file="$tmp"
          IFS= read -r -d "" cwd < "$tmp"
          [ -n "$cwd" ] && [ "$cwd" != "$PWD" ] && [ -d "$cwd" ] && builtin cd -- "$cwd"
          command rm -f -- "$tmp"
      }
    '';
  };

  # ---------------------------------------------------------------------------
  # fzf — replaces the homebrew ~/.fzf.zsh sourcing in .commonrc
  # ---------------------------------------------------------------------------
  programs.fzf = {
    enable = true;
    enableZshIntegration = true; # ^R / ^T / ALT-C + ** completion
  };

  # ---------------------------------------------------------------------------
  # starship — reads your existing starship.toml verbatim
  # ---------------------------------------------------------------------------
  programs.starship = {
    enable = true;
    enableZshIntegration = true;
    settings = builtins.fromTOML (builtins.readFile ./starship.toml);
  };
}
