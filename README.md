# dotfiles

Config for tmux, zsh, and shell utilities.

### requirements

- [GNU Stow](https://www.gnu.org/software/stow/) — `brew install stow`
- [Starship](https://starship.rs) — `brew install starship`

### install

```sh
git clone <repo> ~/git/dotfiles
cd ~/git/dotfiles
./install.sh
```

### structure

- `.zshrc` — zsh entry point, sources `.commonrc`
- `.commonrc` — shared shell config (bash & zsh compatible)
- `.tmux.conf` — tmux config, `C-a` prefix, vi bindings
- `.local/bin/` — shell utilities (`tmux-sessionizer`, `tmux-launcher`)
