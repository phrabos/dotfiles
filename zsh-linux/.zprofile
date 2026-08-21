# ─── PATH ─────────────────────────────────────────────────────────────────────
# Login-shell-only, so zellij panes don't re-prepend on every new pane.
#
# ~/.local/bin holds uv tools (claude, pre-commit) and the Debian name shims
# (bat -> batcat, fd -> fdfind), so it must come before /usr/bin.

export PATH="$HOME/.local/bin:$PATH"
