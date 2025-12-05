# nvm configuration
export NVM_DIR="$HOME/.nvm"
[ -s "/opt/homebrew/opt/nvm/nvm.sh" ] && \. "/opt/homebrew/opt/nvm/nvm.sh"  # This loads nvm
[ -s "/opt/homebrew/opt/nvm/etc/bash_completion.d/nvmc" ] && \. "/opt/homebrew/opt/nvm/etc/bash_completion.d/nvmc"  # This loads nvm bash_completion

# Set command history file
HISTFILE=~/.history

# Prompt configuration
# Allow command coloring
export CLICOLOR=1
# The coloring is set based on the ASCII color modes, consult the following:
# --> https://gist.github.com/JBlond/2fea43a3049b38287e5e9cefc87b2124
# --> zshzle, CHARACTER HIGHLIGHTING
# Grabbed this from oh-my-zsh setup
autoload -U colors && colors
PS1="%F{214}%(2L.🫧.🦄) %n@%F{71}%m %f%f%F{133}%~ %(?..💔) %# %f"

# Add LaTeX to path
export PATH=/Library/TeX/texbin:$PATH

# aliases
alias %=' '
alias l="ls -alh"
alias vim="nvim"
alias lg="lazygit"

# Add python aliases
alias pip="pip3"
alias python="/opt/homebrew/bin/python3"

# Git aliases
alias g="git"

# clang aliases
alias clang++="clang++ -std=c++20"

# rust
. "$HOME/.cargo/env"            # For sh/bash/zsh/ash/dash/pdksh
#source "$HOME/.cargo/env.fish"  # For fish
#source "$HOME/.cargo/env.nu"    # For nushell

export COLORTERM=truecolor

# local binaries
export PATH=~/.local/bin:$PATH

