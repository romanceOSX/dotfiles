{ config, lib, pkgs, isWSL ? false, ... }:
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
    ".local/bin/herdr-sessionizer" = {
      source = ../.local/bin/herdr-sessionizer;
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
    ".local/bin/tmux-remote-shell" = {
      source = ../.local/bin/tmux-remote-shell;
      executable = true;
    };
    ".local/bin/copilot-sessions" = {
      source = ../.local/bin/copilot-sessions;
      executable = true;
    };
    ".local/bin/taskfzf" = {
      source = ../.local/bin/taskfzf;
      executable = true;
    };
    ".local/bin/clipd" = {
      source = ../.local/bin/clipd;
      executable = true;
    };
    ".local/bin/cliph" = {
      source = ../.local/bin/cliph;
      executable = true;
    };
    ".local/bin/ssh-deploy" = {
      source = ../.local/bin/ssh-deploy;
      executable = true;
    };
    ".local/bin/nix-deploy" = {
      source = ../.local/bin/nix-deploy;
      executable = true;
    };
    ".local/bin/netbench" = {
      source = ../.local/bin/netbench;
      executable = true;
    };
    ".local/bin/messaging-stack" = {
      source = ../.local/bin/messaging-stack;
      executable = true;
    };
  }
  # WSL-only helpers — keep these off macOS so they don't bloat that config.
  // lib.optionalAttrs isWSL {
    ".local/bin/wt-set-font" = {
      source = ../.local/bin/wt-set-font;
      executable = true;
    };
    ".local/bin/sfmono-nerd-install" = {
      source = ../.local/bin/sfmono-nerd-install;
      executable = true;
    };
  }
  # macOS-only helpers — streaming scripts talk to alien via Tailscale/Moonlight.
  // lib.optionalAttrs pkgs.stdenv.isDarwin {
    ".local/bin/stream-alien" = {
      source = ../.local/bin/stream-alien;
      executable = true;
    };
    ".local/bin/stream-alien-clean" = {
      source = ../.local/bin/stream-alien-clean;
      executable = true;
    };
  }
  # Linux-only helpers — macOS has its own sshd (Remote Login), so skip it there.
  // lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux {
    ".local/bin/install-sshd-daemon" = {
      source = ../.local/bin/install-sshd-daemon;
      executable = true;
    };
  };
}
