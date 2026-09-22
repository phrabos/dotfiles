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

# ─── ~/.local/bin ─────────────────────────────────────────────────────────────
# Release binaries (starship, atuin, zellij, mise, uv, carapace, wt) and the
# Debian name shims (bat -> batcat, fd -> fdfind) live here, so it must come
# before /usr/bin.
#
# This lives in .zshenv rather than .zprofile because .zprofile is read by
# LOGIN shells only. GDM sources ~/.profile for X11 sessions (which is how XFCE
# picked this up) but Wayland sessions are exec'd directly and never source it,
# so a terminal under Hyprland got a PATH without this and every tool below
# silently vanished. Same guard as the mise block: subshells and zellij panes
# cannot stack duplicate entries.

LOCAL_BIN="$HOME/.local/bin"
case ":$PATH:" in
  *":$LOCAL_BIN:"*) ;;
  *) [ -d "$LOCAL_BIN" ] && export PATH="$LOCAL_BIN:$PATH" ;;
esac
unset LOCAL_BIN

# ─── corepack ─────────────────────────────────────────────────────────────────
# Skip the y/n download prompt, which otherwise hangs CI, scripts, and editor
# tasks the first time a project's pinned pnpm/yarn version isn't cached.

export COREPACK_ENABLE_DOWNLOAD_PROMPT=0

# ─── telemetry opt-out ────────────────────────────────────────────────────────
# Cross-tool convention (consoledonottrack.com) honored by a growing number of
# CLIs. openspec is env-var-only — editing its config file does not stick.

export DO_NOT_TRACK=1
