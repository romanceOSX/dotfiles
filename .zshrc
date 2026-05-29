# Source shared config
source "${${(%):-%x}:A:h}/.commonrc"

# Prompt configuration
autoload -U colors && colors
PS1="%F{214}%(2L.🫧.🦄) %n@%F{71}%m %f%f%F{133}%~ %(?..💔) %# %f"

function vi-yank-clip {
    zle vi-yank
    if command -v pbcopy &>/dev/null; then
        echo "$CUTBUFFER" | pbcopy
    elif command -v xclip &>/dev/null; then
        echo "$CUTBUFFER" | xclip -selection clipboard
    elif command -v wl-copy &>/dev/null; then
        echo "$CUTBUFFER" | wl-copy
    fi
}
zle -N vi-yank-clip
bindkey -M vicmd 'y' vi-yank-clip
