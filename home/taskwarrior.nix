{ pkgs, lib, config, wingtaskServerUrl ? null, wingtaskClientId ? null
, wingtaskEncryptionSecret ? null, ... }:
let
  # Taskwarrior 3.x keeps everything in a single SQLite db (taskchampion.sqlite3)
  # under dataLocation — NOT the flat *.data files of TW 2.x.
  taskDir = config.programs.taskwarrior.dataLocation;
  # TW3 reads hooks from <data.location>/hooks, NOT ~/.config/task/hooks.
  hookDir = "${taskDir}/hooks";

  # WingTask cloud sync (Option B — see docs/taskwarrior.md). serverUrl +
  # clientId come from your WingTask account; encryptionSecret is a value you
  # generate yourself. All three live in local.nix (gitignored, per-machine)
  # and must be IDENTICAL on every machine sharing this task database.
  # `null` on any host that hasn't configured them (e.g. a fresh clone before
  # signup, or a host deliberately left out of the sync mesh).
  wingtaskConfigured = wingtaskServerUrl != null && wingtaskClientId != null;
in
{
  # ===========================================================================
  # Terminal TODO workflow (experimental) — Taskwarrior + TUI + Timewarrior +
  # taskopen, synced via WingTask cloud (TaskChampion protocol) so the same
  # tasks are reachable from the WingTask web/PWA client, not just this repo's
  # machines.
  #
  #   task / taskwarrior-tui   task manager + TUI frontend
  #   timewarrior              time tracking, wired via the on-modify hook
  #   taskopen                 open URLs/files annotated on a task
  #
  # Previously used a serverless Syncthing-replicated local sync dir (no
  # external service) — see git history at commit 01edd671 if you want to
  # revert to that instead.
  # ===========================================================================

  programs.taskwarrior = {
    enable = true;
    # The HM module defaults to taskwarrior2; we want the SQLite-backed v3.
    package = pkgs.taskwarrior3;

    # No stock theme include — we define a full, cohesive set of color rules
    # below instead (see the "color.*" block in config).

    config = {
      confirmation = false; # don't prompt on bulk edits — the TUI is the safety net
      news.version = "3.4.2"; # silence the "new in this version" nag
    }
    # WingTask cloud sync — see docs/taskwarrior.md. Flat quoted keys (not
    # nested `sync.server = { ... }`) for the same reason as the color.* keys
    # above: sync.server.url/client_id and sync.encryption_secret would
    # otherwise need deep-merging across these two optionalAttrs calls.
    // lib.optionalAttrs wingtaskConfigured {
      "sync.server.url" = wingtaskServerUrl;
      "sync.server.client_id" = wingtaskClientId;
    }
    // lib.optionalAttrs (wingtaskEncryptionSecret != null) {
      "sync.encryption_secret" = wingtaskEncryptionSecret;
    }
    // {

      # --- Muted pastel-rainbow theme -----------------------------------------
      # Same palette as the rest of the terminal (prompt / eza / btop / delta),
      # mapped to xterm-256 codes — Taskwarrior 3.x is 256-color only (colorN /
      # rgbRGB / grayN), no 24-bit hex. Muted family from btop/pastel-rainbow:
      #   rose C58EA7→175 · peach C4A07A→180 · yellow AAAA7E→144 · sage 8EAA8E→108
      #   teal 7EAAAA→109 · slate 7E9DAA→103 · lavender 9D8EBB→139
      # Keys MUST be flat dotted strings: TW uses both `color.due` AND
      # `color.due.today` as distinct keys, which would collide if nested.
      # (`color` master switch is on by default — don't set it here, it would
      # collide with the nested color.* keys.)
      "color.overdue" = "color175"; # rose (hottest = most urgent)
      "color.due.today" = "color180 bold"; # peach
      "color.due" = "color144"; # yellow
      "color.active" = "color108 bold"; # sage (running)
      "color.scheduled" = "color109"; # teal
      "color.tagged" = "color103"; # slate
      "color.recurring" = "color139"; # lavender
      "color.blocking" = "color180"; # peach
      "color.blocked" = "color175"; # rose
      "color.header" = "color139"; # lavender
      "color.label" = "color144"; # yellow
      "color.label.sort" = "color144";
      "color.footnote" = "color244"; # dim — just the trailing summary line
      # NB: do NOT set color.tag.none / color.project.none — those match EVERY
      # untagged / projectless task (i.e. most of the list) and, ranking above
      # due/overdue in rule.precedence, would wash the whole table out to a dim
      # near-transparent gray. Leave such rows at the terminal's default fg.
      "color.completed" = "color245"; # dim gray, but readable in `task all`
      "color.deleted" = "color245";
      "color.alternate" = "on color235"; # subtle alt-row background
      "color.uda.priority.H" = "color175"; # rose
      "color.uda.priority.M" = "color180"; # peach
      "color.uda.priority.L" = "color109"; # teal
      "color.calendar.today" = "color108 bold";
      "color.calendar.due" = "color175";
      "color.calendar.due.today" = "color180 bold";
      "color.calendar.holiday" = "color139";
      "color.calendar.weekend" = "on color235";
      "color.burndown.done" = "color108";
      "color.burndown.started" = "color180";
      "color.burndown.pending" = "color103";
      "color.sync.added" = "color108";
      "color.sync.changed" = "color180";
      "color.sync.rejected" = "color175";
      "color.summary.bar" = "on color108";
      "color.summary.background" = "on color236";
      "color.undo.before" = "color175";
      "color.undo.after" = "color108";
      # Recurring tasks: if you use them, set recurrence=on on your PRIMARY
      # machine and recurrence=off on the others to avoid duplicates on sync.
    };
  };

  home.packages = with pkgs; [
    timewarrior # time tracking
    taskopen # open annotations (URLs/files) from a task
  ];

  # --- taskopen config -------------------------------------------------------
  # macOS has `open` instead of `xdg-open`; generate the right opener per platform.
  xdg.configFile."taskopen/taskopenrc".text =
    let opener = if pkgs.stdenv.isDarwin then "open" else "xdg-open";
    in ''
      [General]
      path_ext=${pkgs.taskopen}/share/taskopen/scripts

      [Actions]
      notes.regex = "^Notes\\.(.*)"
      notes.command = "editnote ~/Notes/tasknotes/$UUID.$LAST_MATCH \"$TASK_DESCRIPTION\" $UUID"

      files.regex = "^[\\.\\/~]+.*\\.(.*)"
      files.command = "${opener} $FILE"
      files.filtercommand = "test -e $FILE"

      url.regex = "((?:www|http).*)"
      url.command = "${opener} $LAST_MATCH"

      edit.regex = ".*"
      edit.command = "rawedit $UUID \"$ANNOTATION\""
      delete.regex = ".*"
      delete.command = "task $UUID denotate -- \"$ANNOTATION\" 2>/dev/null"

      [CLI]
      default = default
      alias.default = "normal --exclude=edit,delete"
      alias.files  = "normal --include=files"
      alias.notes  = "normal --include=notes"
      alias.edit   = "normal --include=edit"
      alias.delete = "normal --include=delete"
      alias.raw    = "any --include=delete,edit"
    '';

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
        # Taskwarrior on-exit hook — auto-push to WingTask on change.
        feed=$(cat)
        [ -z "$feed" ] && exit 0                       # nothing changed (read-only)
        case " $* " in *" command:sync "*) exit 0 ;; esac  # don't recurse
        ( ${pkgs.taskwarrior3}/bin/task sync >/dev/null 2>&1 & ) >/dev/null 2>&1
        exit 0
      '';
    };
  };

  programs.zsh.shellAliases = {
    tf = "taskfzf"; # fzf UI for taskwarrior
    todo = "taskfzf";
    tn = "task next"; # what's next
    ta = "task add"; # quick capture
    tsync = "task sync"; # manual sync (auto-sync covers normal use)
  };

  # ---------------------------------------------------------------------------
  # Periodic pull sync — the on-exit hook above already pushes local changes to
  # WingTask immediately, but nothing local triggers a PULL when a task is
  # added/edited from the WingTask web UI or phone PWA. This timer runs
  # `task sync` every 10 minutes so those changes show up here without a
  # manual `tsync`. Only active once WingTask is actually configured.
  #
  # WSL note: systemd --user requires `systemd=true` in /etc/wsl.conf; without
  # it this timer silently won't run — fall back to manual `tsync` there.
  # ---------------------------------------------------------------------------
  systemd.user.services.task-sync = lib.mkIf (wingtaskConfigured && pkgs.stdenv.isLinux) {
    Unit.Description = "Taskwarrior sync with WingTask";
    Service = {
      Type = "oneshot";
      ExecStart = "${pkgs.taskwarrior3}/bin/task sync";
    };
  };

  systemd.user.timers.task-sync = lib.mkIf (wingtaskConfigured && pkgs.stdenv.isLinux) {
    Unit.Description = "Periodic Taskwarrior sync with WingTask";
    Timer = {
      OnStartupSec = "2m";
      OnUnitActiveSec = "10m";
    };
    Install.WantedBy = [ "timers.target" ];
  };

  launchd.agents.task-sync = lib.mkIf (wingtaskConfigured && pkgs.stdenv.isDarwin) {
    enable = true;
    config = {
      ProgramArguments = [ "${pkgs.taskwarrior3}/bin/task" "sync" ];
      StartInterval = 600; # 10 minutes
      StandardOutPath = "/tmp/task-sync.log";
      StandardErrorPath = "/tmp/task-sync.log";
    };
  };
}
