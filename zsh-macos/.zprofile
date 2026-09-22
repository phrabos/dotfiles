eval "$(/opt/homebrew/bin/brew shellenv)"

# ─── PATH ─────────────────────────────────────────────────────────────────────
# ~/.local/bin moved to ~/.zshenv (shared), so it applies to non-login shells
# too. The .zshenv version is guarded against duplicate prepending, which was
# the reason this was login-shell-only.
