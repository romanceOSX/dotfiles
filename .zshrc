# Source shared config
source "${${(%):-%x}:A:h}/.commonrc"

# Makes the zsh's vi-mode yank clipboard-accesible
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

