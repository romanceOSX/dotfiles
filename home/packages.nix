{ pkgs, pkgs-neovim, lib, ... }:
{
    # Toolchains + the CLI utilities the configs/scripts assume on PATH.
    # (zsh, fzf, starship, lazygit, yazi, tmux, git come from their own
    #  program modules in shell.nix / programs.nix / tmux.nix.)
    home.packages =
        [
            # --- editor (config is an out-of-store symlink, see programs.nix) ---
            # Pinned to neovim 0.12.0 — see nixpkgs-neovim in flake.nix.
            # 0.12.2 has a treesitter core regression that crashes
            # render-markdown.nvim with "attempt to call method 'range'
            # (a nil value)" on every cursor move in markdown buffers;
            # 0.11.x lacks features aerial.nvim needs. 0.12.0 predates
            # the regression and supports aerial.
            pkgs-neovim.neovim
        ]
        ++ (with pkgs; [
            # --- toolchains (chosen via setup) ---
            nodejs_22 # Node.js (replaces the homebrew nvm lazy-load on nix hosts)
            rustc
            cargo
            rustfmt
            clippy
            rust-analyzer
            clang # provides clang++ (clang++ -std=c++20 alias)
            clang-tools # provides clangd (matches .clangd)
            tree-sitter # CLI used by nvim-treesitter (main branch) to build parsers
            vimPlugins.nvim-treesitter # nvim-treesitter plugin package

            # --- LSP servers ---
            lua-language-server
            pyright

            # --- formatters / linters ---
            stylua
            black
            python3Packages.isort

            python3 # for the python/pip aliases
            python3Packages.tkinter
            uv # fast Python package and project manager

            # --- utilities used by configs & .local/bin scripts ---
            coreutils # GNU ls/etc. — makes `ls --color` + LS_COLORS work everywhere
            gawk # rainbow-prompt / tmux-rainbow sine-wave gradients
            gnused
            stow # keep the non-nix stow install path working too
            fastfetch
            hyfetch
            colima
            cmake
            macchina
            openai-whisper

            # --- yazi preview dependencies (file previewers) ---
            ffmpeg # video thumbnails / transcoding
            jq # JSON preview + plugin scripts
            poppler-utils # PDF previews (pdftoppm)
            _7zz # archive previews (7zz)
            resvg # SVG previews
            imagemagick # image previews / convert
            chafa # terminal image previewer
            nerd-fonts.symbols-only # glyph icons for prompt + yazi

            # --- modern CLI replacements (aliased in shell.nix) ---
            eza # ls  — listing + tree + git status
            # bat (cat) is wired via programs.bat in programs.nix (themed).
            fd # find — simpler/faster file search
            ripgrep # grep — fast recursive text search
            dust # du  — disk-usage tree
            duf # df  — filesystem usage
            procs # ps  — process listing
            tealdeer # man — `tldr` example-driven docs
            viddy # watch — live command output
            delta # diff — syntax-highlighted diffs (also git pager, see programs.nix)
            # zoxide (cd) is wired via programs.zoxide in shell.nix.
            # fzf (history/fuzzy) is wired via programs.fzf in shell.nix.

            # --- networking ---
            nmap # port scanner
            curl # HTTP client
            dig # DNS lookups (from bind)
            mtr # traceroute + ping combined
        ])
        ++ lib.optionals pkgs.stdenv.isDarwin [
            # `ip` shim wrapping ifconfig/netstat/route. Partial coverage of the
            # real iproute2 (handles `ip addr`/`route`/`link`; no `ss`).
            pkgs.iproute2mac
        ]
        ++ lib.optionals pkgs.stdenv.isLinux [
            # macOS ships these; on Linux pull them in for the scripts/clipboard yank.
            pkgs.xclip
            pkgs.wl-clipboard
            pkgs.inetutils # `hostname` for rainbow-prompt
            pkgs.xdg-utils # provides xdg-open (aliased to `open` in shell.nix)
            pkgs.iproute2 # `ip` / `ss` — Linux-native, not available on macOS
        ];
}
