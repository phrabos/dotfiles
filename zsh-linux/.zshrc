# ─── Environment ──────────────────────────────────────────────────────────────

export EDITOR="nvim"
export VISUAL="nvim"

# PATH (~/.local/bin, mise shims) is set in ~/.zshenv, so every zsh gets it.

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
setopt HIST_FCNTL_LOCK        # kernel file locking: panes writing at once can't corrupt it
setopt HIST_IGNORE_SPACE      # a leading space keeps a command (tokens, passwords) out

# ─── mise (runtime version manager) ──────────────────────────────────────────
# Re-evaluates on every prompt and cd: puts the exact install dirs for the
# versions active in this directory on PATH (ahead of the shims from .zshenv)
# and loads a project mise.toml's [env] / _.path / _.python.venv. Shims alone
# pick the right version per directory but never set those env vars.

eval "$(mise activate zsh)"

# ─── Plugins (Antidote) ──────────────────────────────────────────────────────

# Palette for zsh-syntax-highlighting; must be sourced before the plugin loads.
source ~/.config/zsh/catppuccin_mocha-zsh-syntax-highlighting.zsh

ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE="fg=#6c7086"   # autosuggestion ghost text color

# colored-man-pages builds its colours from $fg_bold etc., which oh-my-zsh
# loads for its plugins but antidote does not; without this every colour is
# an empty string and man pages stay plain.
autoload -Uz colors && colors

# Antidote is not packaged in Debian; it is a git clone at ~/.antidote.
source ~/.antidote/antidote.zsh
antidote load

# ─── Completions ──────────────────────────────────────────────────────────────
# After antidote: zsh-completions only adds its src/ to $fpath, and compinit
# indexes $fpath once - run it earlier and none of those completions exist.
# Before carapace, whose compdef calls need compinit.

autoload -Uz compinit
compinit

# ─── Man pages (colored-man-pages) ───────────────────────────────────────────
# Catppuccin Mocha instead of the plugin's red / green / yellow-on-blue:
# headings mauve, arguments green, and less's status line and search hits as
# base on mauve, like waybar's active workspace. Set after the plugin, which
# reads these at each `man` call.

less_termcap[md]=$'\e[1;38;2;203;166;247m'              # bold -> mauve
less_termcap[mb]=$'\e[1;38;2;243;139;168m'              # blink -> red
less_termcap[us]=$'\e[38;2;166;227;161m'                # underline -> green
less_termcap[so]=$'\e[1;38;2;30;30;46;48;2;203;166;247m' # standout -> base on mauve

# ─── Vi Mode ──────────────────────────────────────────────────────────────────

bindkey -v
export KEYTIMEOUT=1                            # minimal delay switching modes
autoload -Uz edit-command-line
zle -N edit-command-line
bindkey -M vicmd 'v' edit-command-line         # press v in normal mode to edit command in nvim

# p / P paste the system clipboard instead of zsh's own register: wl-paste on
# Wayland, pbpaste on macOS. Text only (--type text), so an image on the
# clipboard is skipped; with no clipboard (ssh, or a Zellij session left over
# from another login) or an empty one, they fall back to zsh's register, i.e.
# the last yank or delete. Paste only - y / d / x still fill zsh's register
# and leave the clipboard alone. The numeric argument (3p) passes through.
_vi_put_clipboard() {
  local clip
  if [[ -n $WAYLAND_DISPLAY ]] && (( $+commands[wl-paste] )); then
    clip=$(timeout 1 wl-paste --no-newline --type text 2>/dev/null)
  elif (( $+commands[pbpaste] )); then
    clip=$(pbpaste 2>/dev/null)
  fi
  [[ -n $clip ]] && CUTBUFFER=$clip
  zle .${WIDGET#clipboard-}
}
zle -N clipboard-vi-put-after  _vi_put_clipboard
zle -N clipboard-vi-put-before _vi_put_clipboard
bindkey -M vicmd 'p' clipboard-vi-put-after
bindkey -M vicmd 'P' clipboard-vi-put-before

# ─── Completion UI ───────────────────────────────────────────────────────────
# zsh/complist provides the menuselect keymap. First Tab prints the list, second
# Tab makes it navigable.

zmodload zsh/complist

setopt COMPLETE_IN_WORD                        # complete from the cursor, not just EOL
setopt ALWAYS_TO_END                           # move to end of word after accepting

zstyle ':completion:*' menu select             # interactive, arrow-navigable menu
zstyle ':completion:*' group-name ''           # group candidates by type...
zstyle ':completion:*:descriptions' format $'\e[1;38;2;203;166;247m-- %d --\e[0m'  # ...under mauve headers
zstyle ':completion:*' verbose true            # show candidate descriptions
zstyle ':completion:*' list-separator '  '     # gap between candidate and description
zstyle ':completion:*' squeeze-slashes true    # collapse repeated / when completing paths
zstyle ':completion:*' list-colors ''          # colour files/dirs in the list (zsh defaults; LS_COLORS is unset)
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Z}'  # lowercase also matches uppercase: doc -> Documents

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
alias ls="eza -lah --icons=auto"               # auto: no icon glyphs when piped
alias lst="eza -lahT '--ignore-glob=node_modules|.log|.git' --icons=auto"
alias lsn="eza -lahs name --icons=auto"
alias lsd="eza -lahs date --icons=auto"

# Navigation
alias .1="cd .."
alias .2="cd ../.."
alias .3="cd ../../.."
alias .4="cd ../../../.."
alias .5="cd ../../../../.."

# Tools
# `bat` and `fd` are the shims in ~/.local/bin; Debian names the binaries
# batcat and fdfind to avoid clashes with unrelated packages.
alias cat="bat"
alias http="xh"
alias gg="lazygit"

# Quick access
alias zshrc="nvim ~/.zshrc"
alias zshrcs="exec zsh"                       # fresh shell; re-sourcing stacks every init twice

# Network
alias weather="curl -4 wttr.in"     # append /<city> to override IP geolocation
alias myip4="xh -4b icanhazip.com"
alias myip6="xh -6b icanhazip.com"
alias speedtest="librespeed-cli"   # FOSS up/down/ping test (LibreSpeed)

# Worktree
alias wtc='wt switch --create --execute="claude --dangerously-skip-permissions"'

# ─── Functions ────────────────────────────────────────────────────────────────

# cd and list contents. Goes through zoxide, so `cx proj` works like `z proj`;
# plain paths behave as before.
cx() {
  z "$@" && ls
}

# ─── Prompt (Starship) ───────────────────────────────────────────────────────

eval "$(starship init zsh)"

# Semantic prompt marks for Zellij scroll mode; must follow starship init.
source ~/.config/zsh/osc133.zsh

# ─── fzf (fuzzy finder) ──────────────────────────────────────────────────────
# Alt+T pastes a file path at the cursor, Alt+C cds into a subdirectory. fzf
# also binds Ctrl+R; atuin loads after this and takes that key back.
# Colours: catppuccin/fzf Mocha, with the pointer / marker / prompt on the
# desktop's mauve and pink, and bg -1 so the translucent terminal shows through.

export FZF_DEFAULT_OPTS=" \
--color=bg+:#313244,bg:-1,spinner:#F5E0DC,hl:#F38BA8 \
--color=fg:#CDD6F4,header:#F38BA8,info:#CBA6F7,pointer:#CBA6F7 \
--color=marker:#F5C2E7,fg+:#CDD6F4,prompt:#CBA6F7,hl+:#F38BA8 \
--color=selected-bg:#45475A \
--color=border:#6C7086,label:#CDD6F4 \
--height=40% --layout=reverse --border=rounded"

# fd respects .gitignore and is far faster than fzf's own `find` walk.
export FZF_CTRL_T_COMMAND='fd --type f --hidden --follow --exclude .git'
export FZF_CTRL_T_OPTS="--preview 'bat --color=always --style=numbers --line-range=:200 {}'"
export FZF_ALT_C_COMMAND='fd --type d --hidden --follow --exclude .git'
export FZF_ALT_C_OPTS="--preview 'eza -T -L 2 --icons=always --color=always {}'"

source <(fzf --zsh)
# fzf also claims Ctrl+R in vi normal mode, where atuin does not rebind it;
# hand it back to vi's redo, as before fzf was loaded.
bindkey -M vicmd '^R' redo
# fzf puts the file picker on Ctrl+T, which Zellij takes in normal mode, so
# it never reaches the shell. Alt+T instead: free in Ghostty, Zellij,
# Hyprland (ALT is its mod key, but nothing uses T) and vi mode, and it
# pairs with Alt+C. The Ctrl+T binding stays for use outside Zellij.
bindkey -M viins '^[t' fzf-file-widget
bindkey -M vicmd '^[t' fzf-file-widget

# ─── Shell History (Atuin) ────────────────────────────────────────────────────
# Binds up-arrow and ^R.

eval "$(atuin init zsh)"

# ─── Tool Integrations ───────────────────────────────────────────────────────

# Worktree shell integration
if command -v wt >/dev/null 2>&1; then
  eval "$(command wt config shell init zsh)"
fi

# --- HTB: wpscan with API token pulled from pass (no secrets in history) ---
# One-time setup: pass insert htb/wpscan-api-token
# Usage: just run `wpscan --url ...` — token is injected automatically.
wpscan() { command wpscan "$@" --api-token "$(pass show htb/wpscan-api-token)"; }

# ─── zoxide (smarter cd) ─────────────────────────────────────────────────────
# `z <part of a path>` jumps to the best match among directories you have
# visited; `zi` picks from them in fzf. zoxide's docs want this last, after
# compinit and anything else that hooks cd.

if command -v zoxide >/dev/null 2>&1; then
  eval "$(zoxide init zsh)"
fi
