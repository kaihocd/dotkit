# Defaults are local to this shell, not the desktop session.
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
export XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"
export XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"

export ZDOTDIR="$XDG_CONFIG_HOME/zsh"

# Machine-local values stay outside the repository.
typeset zsh_local_env="$XDG_CONFIG_HOME/zsh-local/env.zsh"
[[ -r "$zsh_local_env" ]] && source "$zsh_local_env"
unset zsh_local_env

# XDG does not define a directory for user executables.
export PATH="$HOME/.local/bin:$PATH"

# Prefer Neovim for programs that delegate interactive text editing.
if (($+commands[nvim])); then
  export EDITOR=nvim
  export VISUAL=nvim
fi
