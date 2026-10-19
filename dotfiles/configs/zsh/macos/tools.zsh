export SHELL_SESSIONS_DISABLE=1

# Make Homebrew tools available to the interactive shell.
for brew_path in /opt/homebrew/bin/brew /usr/local/bin/brew; do
  if [[ -x "$brew_path" ]]; then
    eval "$("$brew_path" shellenv)"
    break
  fi
done
unset brew_path

# Node and plugins installed by Homebrew.
if [[ -s "$HOMEBREW_PREFIX/opt/nvm/nvm.sh" ]]; then
  source "$HOMEBREW_PREFIX/opt/nvm/nvm.sh" --no-use
fi

source "$HOMEBREW_PREFIX/opt/zinit/zinit.zsh"
zinit light zsh-users/zsh-history-substring-search
zinit light zsh-users/zsh-autosuggestions
zinit light zsh-users/zsh-syntax-highlighting

alias ls='ls -G'
alias ll='ls -lhG'
