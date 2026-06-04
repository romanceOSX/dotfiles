{ pkgs, lib, ... }:
{
  # Toolchains + the CLI utilities the configs/scripts assume on PATH.
  # (zsh, fzf, starship, lazygit, yazi, neovim, tmux, git come from their own
  #  program modules in shell.nix / programs.nix / tmux.nix.)
  home.packages =
    with pkgs;
    [
      # --- toolchains (chosen via setup) ---
      nodejs_22 # Node.js (replaces the homebrew nvm lazy-load on nix hosts)
      rustc
      cargo
      rustfmt
      clippy
      rust-analyzer
      clang # provides clang++ (clang++ -std=c++20 alias)
      clang-tools # provides clangd (matches .clangd)

      python3 # for the python/pip aliases
      python3Packages.tkinter
      uv # fast Python package and project manager

      # --- utilities used by configs & .local/bin scripts ---
      coreutils # GNU ls/etc. — makes `ls --color` + LS_COLORS work everywhere
      gawk # rainbow-prompt / tmux-rainbow sine-wave gradients
      gnused
      bat # tmux `?` keybind popup
      ripgrep
      fd
      stow # keep the non-nix stow install path working too
      fastfetch
      hyfetch
      nmap
    ]
    ++ lib.optionals stdenv.isLinux [
      # macOS ships these; on Linux pull them in for the scripts/clipboard yank.
      xclip
      wl-clipboard
      inetutils # `hostname` for rainbow-prompt
      xdg-utils # provides xdg-open (aliased to `open` in shell.nix)
    ];
}
