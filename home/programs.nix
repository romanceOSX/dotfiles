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
    config.lib.file.mkOutOfStoreSymlink "/Users/romance/git/init.lua";

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
}
