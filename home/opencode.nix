{ ... }:
{
  # opencode: grant full permissions ("yolo") by default.
  #
  # The interactive TUI (`opencode`) has NO CLI flag to skip permission prompts;
  # only `opencode run` does, via `--dangerously-skip-permissions`. So the only
  # way to auto-approve everywhere — TUI and `run` alike — is the config below.
  # `permission = "allow"` auto-approves every action not explicitly denied
  # (PermissionActionConfig enum: ask | allow | deny). See
  # https://opencode.ai/config.json.
  xdg.configFile."opencode/opencode.jsonc".text = builtins.toJSON {
    "$schema" = "https://opencode.ai/config.json";
    permission = "allow";
  };
}
