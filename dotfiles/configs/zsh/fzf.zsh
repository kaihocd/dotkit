# Appearance

typeset -ga _FZF_STYLE=(
  '--height=60%'
  '--layout=reverse'
  '--style=minimal'
  '--border=horizontal'
  '--border-label-pos=3'
  '--input-border=bottom'
  '--prompt=> '
  '--pointer=> '
  '--marker='
  '--no-multi'
  '--bind=ctrl-j:accept'
  '--bind=ctrl-d:half-page-down'
  '--bind=ctrl-u:half-page-up'
  '--info=inline-right'
  '--scrollbar=┊┊'
  '--color=bg:-1,bg+:-1,fg:-1,fg+:15:bold'
  '--color=border:8,input-border:8,info:8,gutter:-1'
  '--color=label:12:bold,input-label:12:bold'
  '--color=prompt:12,pointer:12:bold,hl:12,hl+:12:bold'
)

# Apply the shared appearance and controls to every fzf invocation.
export FZF_DEFAULT_OPTS=${(j: :)${(@q)_FZF_STYLE}}

_fzf_opts() {
  local label=$1
  shift

  local -a opts=(
    "--border-label= $label "
    "$@"
  )

  print -r -- ${(j: :)${(@q)opts}}
}

# Apply one shared preview layout and control scheme around a caller's command.
_fzf_preview_opts() {
  local command=$1
  local -a opts=(
    "--preview=$command"
    '--preview-window=right,60%,border-left,<100(down,50%,border-top)'
    '--bind=ctrl-/:toggle-preview'
    '--bind=ctrl-f:preview-half-page-down'
    '--bind=ctrl-b:preview-half-page-up'
    '--bind=f5:refresh-preview'
  )

  print -r -- ${(j: :)${(@q)opts}}
}

# Product-level search settings.
_FZF_FILE_COMMAND='fd --type f --exclude .git; fd --type f --hidden --exclude .git --full-path "(^|/)\\."'
_FZF_FILE_OPTS="$(_fzf_opts Files) $(_fzf_preview_opts 'bat --color=always --style=numbers --line-range=:500 -- {}')"
_FZF_HISTORY_OPTS=$(
  _fzf_opts History \
    '--bind=enter:accept,ctrl-j:accept'
)
_FZF_DIRECTORY_OPTS=$(_fzf_opts Directories)

# Adapt product semantics to fzf and zoxide's public environment variables.
FZF_CTRL_T_COMMAND=$_FZF_FILE_COMMAND
FZF_CTRL_T_OPTS=$_FZF_FILE_OPTS
FZF_CTRL_R_OPTS=$_FZF_HISTORY_OPTS

# Zoxide replaces FZF_DEFAULT_OPTS rather than extending it.
export _ZO_FZF_OPTS="$FZF_DEFAULT_OPTS $_FZF_DIRECTORY_OPTS"

# Load fzf's shell integration, but disable its Alt-C walker in favor of Ctrl-G.
FZF_ALT_C_COMMAND=''
source <(fzf --zsh)

# Search shortcuts in vi insert mode.
bindkey -M viins '^F' fzf-file-widget
bindkey -M viins '^R' fzf-history-widget

# Search files without using the current command line as the initial query.
fzf-file-widget() {
  local selected ret

  selected="$(__fzf_select)"
  ret=$?
  LBUFFER="${LBUFFER}${selected}"

  zle reset-prompt
  return $ret
}
zle -N fzf-file-widget
bindkey -M viins -r '^T'

# Interactive directory search with zoxide.
zoxide-cd-widget() {
  local dir ret

  dir="$(zoxide query --interactive)"
  ret=$?

  if ((ret == 0)) && [[ -n $dir ]]; then
    BUFFER="builtin cd -- ${(q)dir:a}"
    CURSOR=${#BUFFER}
  fi

  zle reset-prompt
  return $ret
}
zle -N zoxide-cd-widget

# Fuzzy search is available only while editing in vi insert mode.
bindkey -M viins '^G' zoxide-cd-widget
