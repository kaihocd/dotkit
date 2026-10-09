# NVM
export NVM_DIR="$HOME/.nvm"
export NVM_SYMLINK_CURRENT=true
path=(
    "$NVM_DIR/current/bin"
    $path
)
[[ -s "$HOMEBREW_PREFIX/opt/nvm/nvm.sh" ]] && source "$HOMEBREW_PREFIX/opt/nvm/nvm.sh" --no-use

# Smart directory navigation
eval "$(zoxide init zsh --cmd cd)"

# Prompt
eval "$(starship init zsh)"

source "$ZDOTDIR/fzf.zsh"

# Zinit plugins
source "$HOMEBREW_PREFIX/opt/zinit/zinit.zsh"

HISTORY_SUBSTRING_SEARCH_PREFIXED=1
HISTORY_SUBSTRING_SEARCH_GLOBBING_FLAGS=''
HISTORY_SUBSTRING_SEARCH_ENSURE_UNIQUE=1
HISTORY_SUBSTRING_SEARCH_HIGHLIGHT_FOUND='fg=magenta,bold'
HISTORY_SUBSTRING_SEARCH_HIGHLIGHT_NOT_FOUND='fg=red,bold'
zinit light zsh-users/zsh-history-substring-search

zinit light zsh-users/zsh-autosuggestions

zinit light zsh-users/zsh-syntax-highlighting
