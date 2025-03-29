export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion

# My aliases
alias %=' '
alias l="ls -alh"
alias vim="nvim"
alias lg="lazygit"

# Set command history file
HISTFILE=~/.history

##########
# Prompt #
##########
# Allow command coloring
export CLICOLOR=1
# The coloring is set based on the ASCII color modes, consult the following:
# --> https://gist.github.com/JBlond/2fea43a3049b38287e5e9cefc87b2124
# --> zshzle, CHARACTER HIGHLIGHTING
# Grabbed this from oh-my-zsh setup
autoload -U colors && colors
PS1="%F{214}%(2L.🫧.🦄) %n@%F{71}%m %f%f%F{133}%~%(?..💔) %# %f"

# Add LaTeX to path
export PATH=/Library/TeX/texbin:$PATH

# Add python aliases
alias pip="pip3"
alias python="python3"

# Git aliases
alias g="git"

# clangd aliases
alias clang++="clang++ -std=c++20"

