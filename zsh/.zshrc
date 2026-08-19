# ─── Completions ──────────────────────────────────────────────────────────────
# Must run before plugins that register completions.

autoload -Uz compinit
compinit

# ─── Environment ──────────────────────────────────────────────────────────────

export EDITOR="nvim"
export VISUAL="nvim"

# PATH is set in ~/.zprofile, login-shell-only, so zellij panes don't re-prepend it.

# ─── History ──────────────────────────────────────────────────────────────────
# Atuin owns interactive search (up-arrow, ^R). This file is the fallback that
# backs !! / !$ expansion, fc, and anything reading ~/.zsh_history directly.

HISTSIZE=99999
SAVEHIST=$HISTSIZE
HISTFILE=~/.zsh_history

setopt HIST_IGNORE_ALL_DUPS   # drop older copies of a repeated command
setopt HIST_REDUCE_BLANKS     # collapse extra whitespace before saving
setopt SHARE_HISTORY          # zellij panes see each other's commands live
setopt EXTENDED_HISTORY       # record timestamp + duration per entry

# ─── mise (runtime version manager) ──────────────────────────────────────────

eval "$(mise activate zsh)"

# ─── Plugins (Antidote) ──────────────────────────────────────────────────────

# Palette for zsh-syntax-highlighting; must be sourced before the plugin loads.
source ~/.config/zsh/catppuccin_mocha-zsh-syntax-highlighting.zsh

ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE="fg=#6c7086"   # autosuggestion ghost text color

source /opt/homebrew/opt/antidote/share/antidote/antidote.zsh
antidote load

# ─── Vi Mode ──────────────────────────────────────────────────────────────────

bindkey -v
export KEYTIMEOUT=1                            # minimal delay switching modes
autoload -Uz edit-command-line
zle -N edit-command-line
bindkey -M vicmd 'v' edit-command-line         # press v in normal mode to edit command in nvim

# ─── Completion UI ───────────────────────────────────────────────────────────
# zsh/complist provides the menuselect keymap. First Tab prints the list, second
# Tab makes it navigable.

zmodload zsh/complist

setopt COMPLETE_IN_WORD                        # complete from the cursor, not just EOL
setopt ALWAYS_TO_END                           # move to end of word after accepting

zstyle ':completion:*' menu select             # interactive, arrow-navigable menu
zstyle ':completion:*' group-name ''           # group candidates by type, with headers
zstyle ':completion:*' verbose true            # show candidate descriptions
zstyle ':completion:*' list-separator '  '     # gap between candidate and description
zstyle ':completion:*' squeeze-slashes true    # collapse repeated / when completing paths

# menuselect is a separate keymap from vi mode, so it needs its own bindings.
bindkey -M menuselect '^I' menu-complete              # tab steps forward
bindkey -M menuselect 'h' vi-backward-char
bindkey -M menuselect 'j' vi-down-line-or-history
bindkey -M menuselect 'k' vi-up-line-or-history
bindkey -M menuselect 'l' vi-forward-char
bindkey -M menuselect '^[[Z' reverse-menu-complete    # shift-tab steps backwards
bindkey -M menuselect '/' history-incremental-search-forward   # filter the menu
bindkey -M menuselect '^[' send-break                 # esc closes, restores the line

# ─── Carapace (multi-shell completion engine) ────────────────────────────────

export CARAPACE_BRIDGES='inshellisense,zsh'
source <(carapace _carapace)

# ─── Aliases ──────────────────────────────────────────────────────────────────

# File listing (eza)
export EZA_CONFIG_DIR="$HOME/.config/eza"      # directory eza reads theme.yml from
export EZA_COLORS="di=38;2;203;166;247"        # directory name color in long listings
alias ls="eza -lah --icons=always"
alias lst="eza -lahT '--ignore-glob=node_modules|.log|.git' --icons=always"
alias lsn="eza -lahs name --icons=always"
alias lsd="eza -lahs date --icons=always"

# Navigation
alias .1="cd .."
alias .2="cd ../.."
alias .3="cd ../../.."
alias .4="cd ../../../.."
alias .5="cd ../../../../.."

# Tools
alias cat="bat"
alias http="xh"
alias gg="lazygit"

# Quick access
alias zshrc="nvim ~/.zshrc"
alias zshrcs="source ~/.zshrc"

# Network
alias weather="curl -4 wttr.in"     # append /<city> to override IP geolocation
alias myip4="xh -4b icanhazip.com"
alias myip6="xh -6b icanhazip.com"

# Worktree
alias wtc='wt switch --create --execute="claude --dangerously-skip-permissions"'

# ─── Functions ────────────────────────────────────────────────────────────────

# cd and list contents
cx() {
  builtin cd "$@" && ls
}

# ─── Prompt (Starship) ───────────────────────────────────────────────────────

eval "$(starship init zsh)"

# ─── Shell History (Atuin) ────────────────────────────────────────────────────
# Binds up-arrow and ^R.

eval "$(atuin init zsh)"

# ─── Tool Integrations ───────────────────────────────────────────────────────

# Worktree shell integration
if command -v wt >/dev/null 2>&1; then
  eval "$(command wt config shell init zsh)"
fi

# direnv - per-directory environment variables
eval "$(direnv hook zsh)"
