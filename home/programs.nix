{ config, pkgs, ... }:
{
  # ---------------------------------------------------------------------------
  # lazygit — pastel-rainbow theme
  # ---------------------------------------------------------------------------
  programs.lazygit = {
    enable = true;
    settings = {
      gui = {
        nerdFontsVersion = "3";
        theme = {
          activeBorderColor = [ "#C58EA7" "bold" ]; # mauve (matches yazi/tmux)
          inactiveBorderColor = [ "#7E7480" ]; # grey — visible but muted
          searchingActiveBorderColor = [ "#F6CF94" "bold" ]; # peach
          optionsTextColor = [ "#9EC4FE" ]; # blue
          selectedLineBgColor = [ "#3A363B" ]; # bg-hi
          inactiveViewSelectedLineBgColor = [ "#2F2B30" ]; # bg-alt
          cherryPickedCommitFgColor = [ "#191719" ];
          cherryPickedCommitBgColor = [ "#CF94F7" ]; # purple
          markedBaseCommitFgColor = [ "#191719" ];
          markedBaseCommitBgColor = [ "#F6CF94" ]; # peach
          unstagedChangesColor = [ "#FFB3B3" ]; # red
          defaultFgColor = [ "default" ];
        };
        authorColors = {
          "*" = "#94E7E4"; # mint/cyan
        };
        branchColors = {
          master = "#FA9EC4"; # pink
          main = "#FA9EC4"; # pink
          develop = "#B4FA9E"; # green
        };
      };
    };
  };

  # ---------------------------------------------------------------------------
  # yazi — pastel-rainbow theme + per-letter dir gradient init.lua
  # ---------------------------------------------------------------------------
  programs.yazi = {
    enable = true;
    enableZshIntegration = false; # we define our own `y` wrapper in shell.nix
    theme = builtins.fromTOML (builtins.readFile ./yazi/theme.toml);
    initLua = ./yazi/init.lua;
    settings.mgr.show_hidden = true; # show dotfiles by default (toggle with `.`)
  };

  # ---------------------------------------------------------------------------
  # neovim
  #
  # Nix only installs the binary (home.packages below) — it does NOT manage the
  # config. `programs.neovim` is deliberately not used because it generates its
  # own init.lua (provider shims) and would own ~/.config/nvim. Instead the whole
  # config dir is a plain symlink to the standalone repo at ~/git/init.lua, so
  # init.lua / lua / after / colors all come straight from there. Edits are live
  # with no flake input, lock entry, or rebuild. `vim`/`vi` aliases + EDITOR live
  # in shell.nix.
  # ---------------------------------------------------------------------------
  xdg.configFile."nvim".source =
    config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/git/init.lua";

  # markdown-preview.nvim — the preview server needs a Node build (vendored
  # node_modules / a prebuilt binary) that the plugin would otherwise download
  # at first launch via curl+GitHub, which isn't reproducible and silently
  # breaks offline or on uncovered arches. nixpkgs already builds it with the
  # server bundled, so we symlink that store path to a stable location and
  # point lazy's `dir` at it (see init.lua render.lua) — no build step, no
  # network at launch, identical on every host.
  home.file.".local/share/nvim/nix-plugins/markdown-preview.nvim".source =
    pkgs.vimPlugins.markdown-preview-nvim;

  # eza — full pastel-rainbow theme in hex, so every category (incl. file-type
  # classes like `build`) is truecolor and nothing falls back to a 16-colour
  # terminal slot. Complements EZA_COLORS/LS_COLORS in shell.nix.
  xdg.configFile."eza/theme.yml".source = ./eza-theme.yml;

  # clangd — user-global config (migrated from the repo's .clangd). clangd reads
  # per-user config from $XDG_CONFIG_HOME/clangd/config.yaml (same YAML schema as
  # a project-local .clangd); ~/.clangd is NOT a clangd config path, so deploying
  # here is what actually makes clangd pick it up. Forces C++23 on C++ TUs.
  xdg.configFile."clangd/config.yaml".text = ''
    CompileFlags:
      # generic config

    If:
      Language: C++
    CompileFlags:
      Add: [-std=c++23]
  '';

  # ---------------------------------------------------------------------------
  # git — identity is deliberately NOT Nix-managed. Home Manager owns
  # ~/.config/git/config (read-only symlink into the store), but the user
  # identity lives in a plain, machine-local file pulled in via [include].
  # That file (~/.config/git/config.local) is yours to create/edit freely —
  # no local.nix, no `home-manager switch`. Git silently ignores it when
  # absent, so a fresh machine still works. Set your identity with:
  #   git config -f ~/.config/git/config.local user.name  "Your Name"
  #   git config -f ~/.config/git/config.local user.email "you@example.com"
  # ---------------------------------------------------------------------------
  programs.git = {
    enable = true;
    settings = {
      init.defaultBranch = "master";
      include.path = "~/.config/git/config.local";
    };
  };

  # bat — `cat` replacement / pager. "Coldark-Dark" is a soft, muted theme that
  # sits well next to the pastel-rainbow palette; delta shares it below.
  programs.bat = {
    enable = true;
    config.theme = "Coldark-Dark";
  };

  # btop — `top` replacement / interactive monitor. "pastel-rainbow" is a custom
  # muted full-spectrum palette (NOT one of btop's bundled themes), so the theme
  # file ships from this repo into ~/.config/btop/themes and is selected below.
  # Previously it only existed as a hand-placed file on the mac, so it was missing
  # in the dev container and on every other machine. theme_background = false
  # because the theme leaves main_bg empty (uses the terminal background).
  programs.btop = {
    enable = true;
    settings = {
      color_theme = "pastel-rainbow";
      theme_background = false;
      truecolor = true;
      update_ms = 2100;
      proc_tree = true;
      proc_per_core = true;
      proc_mem_bytes = true;
      presets = "cpu:1:default,proc:0:default cpu:0:default,mem:0:default,net:0:default cpu:0:block,net:0:tty";
    };
  };
  xdg.configFile."btop/themes/pastel-rainbow.theme".source =
    ./btop/pastel-rainbow.theme;

  # aoe (agent-of-empires) — custom muted pastel-rainbow theme. aoe owns its
  # config.toml (machine-local, it rewrites it), so we only ship the theme file
  # here; activate it with `[theme] name = "pastel-rainbow"` in config.toml or
  # via aoe's Settings.
  xdg.configFile."agent-of-empires/themes/pastel-rainbow.toml".source =
    ./aoe/pastel-rainbow.toml;

  # delta — syntax-highlighted pager for `git diff` / `git show` / `git log -p`.
  # (Standalone `delta` is also aliased to `diff` for ad-hoc file compares.)
  # Pastel-rainbow palette: rose C58EA7 · mint 94F7E4 · green B4FA9E ·
  # purple CF94F7 · peach F6CF94 · blue 9EC4FE · pink FA9EC4.
  programs.delta = {
    enable = true;
    enableGitIntegration = true;
    options = {
      navigate = true; # n / N to jump between files in the diff
      line-numbers = true;
      syntax-theme = "Coldark-Dark"; # match bat
      # added/removed line backgrounds — muted sage / dusty rose
      plus-style = "syntax #243026";
      plus-emph-style = "syntax #38503f";
      minus-style = "syntax #34232b";
      minus-emph-style = "syntax #5a3a48";
      # gutter line numbers in pastel
      line-numbers-plus-style = "#B4FA9E"; # green
      line-numbers-minus-style = "#FA9EC4"; # pink
      line-numbers-zero-style = "#5A5058"; # dim
      line-numbers-left-style = "#5A5058";
      line-numbers-right-style = "#5A5058";
      # file + hunk headers
      file-style = "#CF94F7"; # purple
      file-decoration-style = "#CF94F7 ul";
      hunk-header-style = "syntax";
      hunk-header-decoration-style = "#94F7E4 box"; # mint
      hunk-header-line-number-style = "#9EC4FE"; # blue
    };
  };
}
