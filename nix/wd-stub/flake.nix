{
  # Empty stand-in for the private `work-dotfiles` flake input.
  #
  # The real input (git+ssh to a personal GitHub repo) is only consumed by the
  # osx/work hosts, but Nix fetches ALL flake inputs eagerly — so a node that
  # can't reach the private repo (e.g. the JD work box, whose git identity has
  # no access) can't build ANY output, including `.#wsl`, which never uses it.
  #
  # On such a node, `--override-input work-dotfiles path:./nix/wd-stub` swaps the
  # real input for this stub so evaluation proceeds. The stub exports the same
  # attribute the real one does — a pure Home Manager module — but empty, which
  # is a no-op for the hosts (wsl) that don't import it anyway. The `hm-switch`
  # wrapper (.local/bin/hm-switch) applies this override automatically when the
  # real input is unreachable. See flake.nix + AGENTS.md.
  description = "Empty stand-in for the private work-dotfiles input";

  outputs = { self, ... }: {
    homeModules.default = { ... }: { };
  };
}
