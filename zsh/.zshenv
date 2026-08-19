# .zshenv is sourced by EVERY zsh — interactive, non-interactive, `ssh host cmd`,
# and scripts. Only things that must exist everywhere belong here.

# ─── mise shims ───────────────────────────────────────────────────────────────
# Puts `node` etc. on PATH in contexts that never read .zshrc. Interactive shells
# still get exact binary paths, since `mise activate` in .zshrc runs ahead of
# these. Guarded so nested subshells don't stack duplicate PATH entries.

MISE_SHIMS="$HOME/.local/share/mise/shims"
case ":$PATH:" in
  *":$MISE_SHIMS:"*) ;;
  *) export PATH="$MISE_SHIMS:$PATH" ;;
esac
unset MISE_SHIMS

# ─── corepack ─────────────────────────────────────────────────────────────────
# Skip the y/n download prompt, which otherwise hangs CI, scripts, and editor
# tasks the first time a project's pinned pnpm/yarn version isn't cached.

export COREPACK_ENABLE_DOWNLOAD_PROMPT=0

# ─── telemetry opt-out ────────────────────────────────────────────────────────
# Cross-tool convention (consoledonottrack.com) honored by a growing number of
# CLIs. openspec is env-var-only — editing its config file does not stick.

export DO_NOT_TRACK=1
