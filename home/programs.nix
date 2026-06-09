{ config, ... }:
{
  # ---------------------------------------------------------------------------
  # lazygit — pastel-rainbow theme (translated from .config/lazygit/config.yml)
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

  # eza — full pastel-rainbow theme in hex, so every category (incl. file-type
  # classes like `build`) is truecolor and nothing falls back to a 16-colour
  # terminal slot. Complements EZA_COLORS/LS_COLORS in shell.nix.
  xdg.configFile."eza/theme.yml".source = ./eza-theme.yml;

  # ---------------------------------------------------------------------------
  # git — identity (no .gitconfig was tracked in the repo; adjust as needed)
  # ---------------------------------------------------------------------------
  programs.git = {
    enable = true;
    settings = {
      user.name = "romance";
      user.email = "romanceosx@gmail.com";
      init.defaultBranch = "master";
    };
  };

  # bat — `cat` replacement / pager. "Coldark-Dark" is a soft, muted theme that
  # sits well next to the pastel-rainbow palette; delta shares it below.
  programs.bat = {
    enable = true;
    config.theme = "Coldark-Dark";
  };

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
