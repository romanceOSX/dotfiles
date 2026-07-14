# direnv + nix-direnv — per-directory environments and fast .env loading.
#
# Why this exists: editing a secret / API key should not require a Home Manager
# rebuild. direnv sources a machine-local, gitignored ./.env the instant you cd
# into a repo (via `dotenv_if_exists` in .envrc), so credentials change without
# any Nix evaluation. nix-direnv adds the `use flake` helper + a persistent
# eval cache so entering a flake dir doesn't re-evaluate every time.
#
# The shell hook is wired automatically for whichever shells are enabled.
{ ... }:
{
  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;

    # Shell init hooks — Home Manager injects `eval "$(direnv hook <shell>)"`.
    enableZshIntegration = true;
    enableBashIntegration = true;
    enableFishIntegration = true;

    # Silence direnv's status chatter ("loading .envrc" / "export +VAR") so
    # entering a dir doesn't clutter the prompt. log_filter is a WHITELIST regex
    # — only matching log lines are shown — so "^$" (matches nothing) hides all
    # informational output. Genuine errors (blocked .envrc, failed commands) use
    # a separate path and STILL surface, so this doesn't hide real problems.
    # NB: on direnv 2.37 an empty DIRENV_LOG_FORMAT does NOT silence (it falls
    # back to the default format); log_filter is the reliable lever.
    config.global.log_filter = "^$";

    # Load a bare ./.env from the current directory even when there is no
    # .envrc. By default direnv only sources .envrc, so a lone .env is ignored
    # ("No .envrc or .env found"). With load_dotenv = true, `direnv allow`ing a
    # directory that has a .env (and no .envrc) exports its vars automatically.
    config.global.load_dotenv = true;
  };
}
