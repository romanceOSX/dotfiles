{ pkgs, lib, config, ... }:
let
  # Taskwarrior 3.x keeps everything in a single SQLite db (taskchampion.sqlite3)
  # under dataLocation — NOT the flat *.data files of TW 2.x. This matters for
  # sync (see the Syncthing block below).
  taskDir = config.programs.taskwarrior.dataLocation;
in
{
  # ===========================================================================
  # Terminal TODO workflow (experimental) — Taskwarrior + TUI + Timewarrior +
  # taskopen, file-synced across Mac/WSL via Syncthing.
  #
  #   task / taskwarrior-tui   task manager + TUI frontend
  #   timewarrior              time tracking, wired via the on-modify hook
  #   taskopen                 open URLs/files annotated on a task
  #
  # WSL note: per the chosen architecture, Syncthing runs on the *Windows host*
  # (not inside WSL). On WSL, point taskwarrior at the Windows-synced folder by
  # symlinking ~/.local/share/task -> /mnt/c/Users/<you>/task (or set
  # dataLocation in local.nix). Only macOS runs the Syncthing service here.
  # ===========================================================================

  programs.taskwarrior = {
    enable = true;
    # The HM module defaults to taskwarrior2; we want the SQLite-backed v3.
    package = pkgs.taskwarrior3;
    # dataLocation defaults to $XDG_DATA_HOME/task (~/.local/share/task) — this
    # is the directory Syncthing replicates.

    # Muted theme to match the rest of the pastel terminal setup.
    # NB: the HM module appends ".theme" to a string value, so omit it here.
    colorTheme = "${pkgs.taskwarrior3}/share/doc/task/rc/dark-gray-blue-256";

    config = {
      confirmation = false; # don't prompt on bulk edits — the TUI is the safety net
      news.version = "3.4.2"; # silence the "new in this version" nag
      # Hooks (incl. the timewarrior bridge below) live in the default
      # $XDG_CONFIG_HOME/task/hooks; no override needed.
    };
  };

  home.packages = with pkgs; [
    taskwarrior-tui # TUI frontend (the yazi/lazygit of tasks)
    timewarrior # time tracking
    taskopen # open annotations (URLs/files) from a task
  ];

  # Timewarrior <-> Taskwarrior bridge: shipping hook that starts/stops a timew
  # interval whenever a task is started/stopped. Deployed executable into the
  # taskwarrior hooks dir.
  home.file.".config/task/hooks/on-modify.timewarrior" = {
    source = "${pkgs.timewarrior}/share/doc/timew/ext/on-modify.timewarrior";
    executable = true;
  };

  programs.zsh.shellAliases = {
    tt = "taskwarrior-tui"; # jump straight into the TUI
    tn = "task next"; # what's next
    ta = "task add"; # quick capture
  };

  # ---------------------------------------------------------------------------
  # Syncthing (macOS only — WSL uses the Windows host's Syncthing).
  #
  # File-syncs the taskwarrior data dir. Because TW3 is a live SQLite db, this
  # carries a corruption risk if two machines write at once — `versioning`
  # keeps the last 10 copies of each file so a bad sync can be rolled back.
  # Pair the Windows device + accept this folder from the Syncthing GUI
  # (http://127.0.0.1:8384), or add the device id under settings.devices.
  # ---------------------------------------------------------------------------
  services.syncthing = lib.mkIf pkgs.stdenv.isDarwin {
    enable = true;
    settings.folders."taskwarrior" = {
      path = taskDir;
      devices = [ ]; # add your Windows device name here once paired
      versioning = {
        type = "simple";
        params.keep = "10";
      };
    };
  };
}
