{ pkgs, lib, config, isWSL ? false, ... }:
let
  # Taskwarrior 3.x keeps everything in a single SQLite db (taskchampion.sqlite3)
  # under dataLocation — NOT the flat *.data files of TW 2.x.
  taskDir = config.programs.taskwarrior.dataLocation;
  # TW3 reads hooks from <data.location>/hooks, NOT ~/.config/task/hooks.
  hookDir = "${taskDir}/hooks";
  # Option A — TaskChampion *local* sync: `task sync` reconciles the local db
  # against an on-disk operation-log server (its own sqlite). This dir — NOT the
  # live db — is what Syncthing replicates across machines. A stale copy just
  # re-merges on the next sync, so you don't lose tasks the way a raw-db file
  # conflict would. No external service, no cloud, no encryption secret required.
  syncDir = "${config.xdg.dataHome}/task-sync";

  # Public Syncthing Device IDs of every machine in your sync mesh. These are
  # PUBLIC and safe to commit — the only secret is each machine's key.pem, which
  # stays machine-local and is NEVER in this repo. The SAME list runs on every
  # machine: each treats the others as peers (and ignores its own entry), so a
  # machine that pulls this config already knows who its peers are.
  #
  # To add a machine: run `syncthing --device-id` on it, add it below, then push
  # + pull + `home-manager switch` everywhere. Placeholders are commented because
  # an invalid id would break Syncthing's config. See docs/taskwarrior.md.
  syncthingDevices = {
    osx-mac.id = "3BEN5LQ-MRXHMAL-764ULF7-R3B2GXO-5SSUXVX-IGBFP7Q-2IBCZZO-3DGDLAY";

    # windows-host = {
    #   id = "XXXXXXX-XXXXXXX-XXXXXXX-XXXXXXX-XXXXXXX-XXXXXXX-XXXXXXX-XXXXXXX";
    #   introducer = true; # always-on hub: auto-introduces new peers to the rest
    # };
    # work.id = "XXXXXXX-XXXXXXX-XXXXXXX-XXXXXXX-XXXXXXX-XXXXXXX-XXXXXXX-XXXXXXX";
  };
in
{
  # ===========================================================================
  # Terminal TODO workflow (experimental) — Taskwarrior + TUI + Timewarrior +
  # taskopen, synced across Mac/WSL with TaskChampion local sync over Syncthing.
  #
  #   task / taskwarrior-tui   task manager + TUI frontend
  #   timewarrior              time tracking, wired via the on-modify hook
  #   taskopen                 open URLs/files annotated on a task
  #
  # WSL note: per the chosen architecture Syncthing runs on the *Windows host*
  # (not inside WSL). On WSL, point the sync dir at the Windows-synced folder by
  # symlinking ~/.local/share/task-sync -> /mnt/c/Users/<you>/task-sync. Only
  # macOS runs the Syncthing service here. The local db (dataLocation) is NOT
  # synced and stays per-machine.
  # ===========================================================================

  programs.taskwarrior = {
    enable = true;
    # The HM module defaults to taskwarrior2; we want the SQLite-backed v3.
    package = pkgs.taskwarrior3;

    # Muted theme to match the rest of the pastel terminal setup.
    # NB: the HM module appends ".theme" to a string value, so omit it here.
    colorTheme = "${pkgs.taskwarrior3}/share/doc/task/rc/dark-gray-blue-256";

    config = {
      confirmation = false; # don't prompt on bulk edits — the TUI is the safety net
      news.version = "3.4.2"; # silence the "new in this version" nag
      # Option A: local, serverless sync target (replicated by Syncthing).
      sync.local.server_dir = syncDir;
      # Optional hardening: to encrypt the synced op-log at rest, set the SAME
      # secret on every machine (keep it out of git — e.g. in local.nix):
      #   sync.encryption_secret = "<shared-secret>";
      # Recurring tasks: if you use them, set recurrence=on on your PRIMARY
      # machine and recurrence=off on the others to avoid duplicates on sync.
    };
  };

  home.packages = with pkgs; [
    taskwarrior-tui # TUI frontend (the yazi/lazygit of tasks)
    timewarrior # time tracking
    taskopen # open annotations (URLs/files) from a task
  ];

  # --- Hooks (deployed into <data.location>/hooks) ---------------------------
  home.file = {
    # Timewarrior <-> Taskwarrior bridge: starts/stops a timew interval when a
    # task is started/stopped.
    "${hookDir}/on-modify.timewarrior" = {
      source = "${pkgs.timewarrior}/share/doc/timew/ext/on-modify.timewarrior";
      executable = true;
    };

    # Auto-sync: after any command that CHANGED data (non-empty stdin feed) and
    # isn't itself a sync (recursion guard), fire `task sync` detached so the
    # CLI/TUI never blocks. on-exit fires for every command, hence both gates.
    "${hookDir}/on-exit.task-sync" = {
      executable = true;
      text = ''
        #!/bin/sh
        # Taskwarrior on-exit hook — auto local-sync on change (Option A).
        feed=$(cat)
        [ -z "$feed" ] && exit 0                       # nothing changed (read-only)
        case " $* " in *" command:sync "*) exit 0 ;; esac  # don't recurse
        ( ${pkgs.taskwarrior3}/bin/task sync >/dev/null 2>&1 & ) >/dev/null 2>&1
        exit 0
      '';
    };
  };

  programs.zsh.shellAliases = {
    tt = "taskwarrior-tui"; # jump straight into the TUI
    todo = "taskwarrior-tui"; # alias for the TUI
    tn = "task next"; # what's next
    ta = "task add"; # quick capture
    tsync = "task sync"; # manual sync (auto-sync covers normal use)
  };

  # ---------------------------------------------------------------------------
  # Syncthing — runs on macOS and bare Linux, but NOT under WSL (there the
  # Windows host runs Syncthing and WSL just symlinks into the synced folder).
  #
  # Replicates the local-sync op-log dir (NOT the live db). `versioning` keeps
  # the last 10 copies as an extra safety net. Peers come from syncthingDevices
  # above; accept/inspect the folder from the GUI (http://127.0.0.1:8384).
  # ---------------------------------------------------------------------------
  services.syncthing = lib.mkIf (pkgs.stdenv.isDarwin || (pkgs.stdenv.isLinux && !isWSL)) {
    enable = true;
    # overrideDevices/overrideFolders default to true, so this declared set is
    # the source of truth — devices/folders added via the GUI get reverted on
    # activation. Keep all machines in syncthingDevices above.
    settings = {
      devices = syncthingDevices;
      folders."taskwarrior-sync" = {
        path = syncDir;
        devices = builtins.attrNames syncthingDevices; # share with every declared peer
        versioning = {
          type = "simple";
          params.keep = "10";
        };
      };
    };
  };
}
