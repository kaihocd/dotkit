# Editing mode
export KEYTIMEOUT=1
bindkey -v

# Delete a Vim-style word without stopping at the point where Insert mode began.
vim-backward-kill-word() {
  local end=$CURSOR

  zle vi-backward-word
  MARK=$CURSOR
  CURSOR=$end
  zle kill-region
}

zle -N vim-backward-kill-word

# Insert mode
bindkey -M viins '^?' backward-delete-char
bindkey -M viins '^H' backward-delete-char
bindkey -M viins '^U' backward-kill-line
bindkey -M viins '^W' vim-backward-kill-word

bindkey -M viins '^[[A' history-substring-search-up
bindkey -M viins '^[[B' history-substring-search-down

# Command mode
bindkey -M vicmd 'j' undefined-key
bindkey -M vicmd 'k' undefined-key
bindkey -M vicmd '^N' down-history
bindkey -M vicmd '^P' up-history

# Use the macOS system clipboard for vi-style paste commands.
vi-system-clipboard-put-after() {
  CUTBUFFER="$(pbpaste)" || return 1
  zle vi-put-after
}

vi-system-clipboard-put-before() {
  CUTBUFFER="$(pbpaste)" || return 1
  zle vi-put-before
}

zle -N vi-system-clipboard-put-after
zle -N vi-system-clipboard-put-before
bindkey -M vicmd 'p' vi-system-clipboard-put-after
bindkey -M vicmd 'P' vi-system-clipboard-put-before

# Open the shared history file in the configured editor.
history-edit() {
  [[ -n "$HISTFILE" ]] || return 1
  "${VISUAL:-${EDITOR:-vi}}" "$HISTFILE"
}

edit-history-file() {
  zle -I
  history-edit </dev/tty >/dev/tty
  local status=$?
  zle reset-prompt
  return $status
}

zle -N edit-history-file
bindkey -M viins '^X^H' edit-history-file
bindkey -M vicmd '^X^H' edit-history-file

# Completion menu
# Keep Tab available to fzf while adding reverse and spatial menu navigation.
bindkey -M viins "$terminfo[kcbt]" reverse-menu-complete
bindkey -M menuselect '^I' menu-complete
bindkey -M menuselect "$terminfo[kcbt]" reverse-menu-complete
bindkey -M menuselect 'h' backward-char
bindkey -M menuselect 'j' down-line-or-history
bindkey -M menuselect 'k' up-line-or-history
bindkey -M menuselect 'l' forward-char
