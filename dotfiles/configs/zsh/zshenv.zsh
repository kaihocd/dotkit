typeset -a missing_xdg_names
for xdg_name in XDG_CONFIG_HOME XDG_DATA_HOME XDG_CACHE_HOME XDG_STATE_HOME; do
  [[ -n ${(P)xdg_name} ]] || missing_xdg_names+=("$xdg_name")
done
unset xdg_name

if (( ${#missing_xdg_names} )); then
  print -u2 -r -- "DOTFILES_ERROR Profiles XDG environment is unavailable: ${(j:, :)missing_xdg_names}"
  unset missing_xdg_names
  return 1
fi
unset missing_xdg_names

export SHELL_SESSIONS_DISABLE=1
export ZDOTDIR="$XDG_CONFIG_HOME/zsh"

# Homebrew is needed before .zshrc loads tools from its prefix.
for brew_path in /opt/homebrew/bin/brew /usr/local/bin/brew; do
  if [[ -x "$brew_path" ]]; then
    eval "$("$brew_path" shellenv)"
    break
  fi
done
unset brew_path

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
