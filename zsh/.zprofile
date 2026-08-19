eval "$(/opt/homebrew/bin/brew shellenv)"

# ─── PATH ─────────────────────────────────────────────────────────────────────
# Login-shell-only, so zellij panes don't re-prepend on every new pane.

export PATH="$HOME/.local/bin:$PATH"                  # claude, pre-commit (uv tools)
