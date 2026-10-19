# NVM
export NVM_DIR="$HOME/.nvm"
export NVM_SYMLINK_CURRENT=true
path=(
  "$NVM_DIR/current/bin"
  $path
)

# Shared plugin settings; the platform entry owns loading.
HISTORY_SUBSTRING_SEARCH_PREFIXED=1
HISTORY_SUBSTRING_SEARCH_GLOBBING_FLAGS=''
HISTORY_SUBSTRING_SEARCH_ENSURE_UNIQUE=1
HISTORY_SUBSTRING_SEARCH_HIGHLIGHT_FOUND='fg=magenta,bold'
HISTORY_SUBSTRING_SEARCH_HIGHLIGHT_NOT_FOUND='fg=red,bold'

# Optional extension selected by deployment, not by operating-system detection.
if [[ -r "$ZDOTDIR/platform-tools.zsh" ]]; then
  source "$ZDOTDIR/platform-tools.zsh"
fi

# Smart directory navigation
eval "$(zoxide init zsh --cmd cd)"

# Prompt
eval "$(starship init zsh)"

source "$ZDOTDIR/fzf.zsh"
