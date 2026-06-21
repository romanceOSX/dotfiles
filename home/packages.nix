{ pkgs, pkgs-neovim, aoe, lib, ... }:
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

            # --- AI agent session manager (flake input, see flake.nix) ---
            # `aoe` — run multiple AI coding agents in parallel across branches.
            # null on hosts where includeAoe = false (e.g. Pi — no aarch64 cache).
        ]
        ++ lib.optional (aoe != null) aoe
        ++ (with pkgs; [
            # --- toolchains (chosen via setup) ---
            nodejs_22 # Node.js (replaces the homebrew nvm lazy-load on nix hosts)
            rustc
            cargo
            rustfmt
            clippy
            rust-analyzer
            clang # provides clang++ (clang++ -std=c++20 alias)
            clang-tools # provides clangd (config in home/programs.nix → ~/.config/clangd)
            tree-sitter # CLI used by nvim-treesitter (main branch) to build parsers
            vimPlugins.nvim-treesitter # nvim-treesitter plugin package

            # --- LSP servers ---
            lua-language-server
            pyright
            bash-language-server # `bashls` — also attached to zsh (see nvim lsp.lua)
            marksman # `marksman` — markdown LSP: link nav, heading completion, rename

            # --- formatters / linters ---
            stylua
            black
            python3Packages.isort
            prettier # markdown formatter (conform format-on-save, see nvim lsp.lua)
            mdformat # markdown formatter — conform fallback when prettier is absent

            python3 # for the python/pip aliases
            python3Packages.tkinter
            uv # fast Python package and project manager

            # --- utilities used by configs & .local/bin scripts ---
            coreutils # GNU ls/etc. — makes `ls --color` + LS_COLORS work everywhere
            gawk # rainbow-prompt / tmux-rainbow sine-wave gradients
            gnused
            stow # keep the non-nix stow install path working too
            # gh (GitHub CLI) is wired via programs.gh in programs.nix
            # (declares gh-dash + gh-notify TUI extensions there too).
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
            dua # du  — interactive disk-usage analyzer
            duf # df  — filesystem usage
            procs # ps  — process listing
            tealdeer # man — `tldr` example-driven docs
            viddy # watch — live command output
            delta # diff — syntax-highlighted diffs (also git pager, see programs.nix)
            # zoxide (cd) is wired via programs.zoxide in shell.nix.
            # fzf (history/fuzzy) is wired via programs.fzf in shell.nix.

            just # command runner (Makefile alternative)
            tokscale # token usage tracker for agentic coding tools (Claude Code, etc.)
            phoronix-test-suite # open-source automated benchmarking suite

            # --- networking ---
            nmap # port scanner
            curl # HTTP client
            dig # DNS lookups (from bind)
            mtr # traceroute + ping combined
            tailscale # mesh VPN — remote access between machines
            sshm # SSH bookmark manager
            assh # SSH proxy/wrapper with advanced config
        ])
        ++ lib.optionals pkgs.stdenv.isDarwin [
            # `ip` shim wrapping ifconfig/netstat/route. Partial coverage of the
            # real iproute2 (handles `ip addr`/`route`/`link`; no `ss`).
            pkgs.iproute2mac
            # pngpaste — dumps the clipboard image to a file; used by img-clip.nvim
            # (<leader>p) to paste screenshots into markdown. See nvim imgclip.lua.
            pkgs.pngpaste
        ]
        ++ lib.optionals pkgs.stdenv.isLinux [
            # macOS ships these; on Linux pull them in for the scripts/clipboard yank.
            pkgs.xclip
            pkgs.wl-clipboard
            pkgs.cliphist
            pkgs.inetutils # `hostname` for rainbow-prompt
            pkgs.xdg-utils # provides xdg-open (aliased to `open` in shell.nix)
            pkgs.iproute2 # `ip` / `ss` — Linux-native, not available on macOS
            # openssh provides `sshd` for the WSL ssh service (remote access into
            # this machine). macOS ships its own sshd, so this is Linux-only.
            # Use the GSSAPI-enabled build: this package's `ssh` shadows the
            # system client on PATH, and the corporate /etc/ssh/ssh_config sets
            # `GSSAPIAuthentication yes`. A non-GSSAPI openssh compiles that
            # keyword out and prints "Unsupported option gssapiauthentication"
            # on every ssh/scp/git-over-ssh call; the gssapi build recognizes it.
            pkgs.openssh_gssapi
        ];
}
