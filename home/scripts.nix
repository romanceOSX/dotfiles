{ config, ... }:
{
  # The shell utilities from .local/bin, copied verbatim into ~/.local/bin with
  # the executable bit set. starship (rainbow-prompt) and tmux (tmux-rainbow,
  # tmux-sessionizer, tmux-launcher) call these by name; ~/.local/bin is put on
  # PATH via home.sessionPath in shell.nix.
  home.file = {
    ".local/bin/rainbow-prompt" = {
      source = ../.local/bin/rainbow-prompt;
      executable = true;
    };
    ".local/bin/tmux-rainbow" = {
      source = ../.local/bin/tmux-rainbow;
      executable = true;
    };
    ".local/bin/tmux-sessionizer" = {
      source = ../.local/bin/tmux-sessionizer;
      executable = true;
    };
    ".local/bin/tmux-launcher" = {
      source = ../.local/bin/tmux-launcher;
      executable = true;
    };
    ".local/bin/install-tailscaled-daemon" = {
      source = ../.local/bin/install-tailscaled-daemon;
      executable = true;
    };
    ".local/bin/tmux-sessionizer-menu" = {
      source = ../.local/bin/tmux-sessionizer-menu;
      executable = true;
    };
    ".local/bin/wsl-sync-dns" = {
      source = ../.local/bin/wsl-sync-dns;
      executable = true;
    };
    ".local/bin/fix-sudo-path" = {
      source = ../.local/bin/fix-sudo-path;
      executable = true;
    };
    ".local/bin/tmux-resurrect-prune" = {
      source = ../.local/bin/tmux-resurrect-prune;
      executable = true;
    };
    ".local/bin/tmux-conf-info" = {
      source = ../.local/bin/tmux-conf-info;
      executable = true;
    };
    ".local/bin/tmux-continuum-ensure-hook" = {
      source = ../.local/bin/tmux-continuum-ensure-hook;
      executable = true;
    };
    ".local/bin/enable-wake-on-lan" = {
      source = ../.local/bin/enable-wake-on-lan;
      executable = true;
    };
    ".local/bin/tmux-agent-monitor" = {
      source = ../.local/bin/tmux-agent-monitor;
      executable = true;
    };
    ".local/bin/tmux-ssh-menu" = {
      source = ../.local/bin/tmux-ssh-menu;
      executable = true;
    };
  };
}
