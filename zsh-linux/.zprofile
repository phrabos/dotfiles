# ─── PATH, again ──────────────────────────────────────────────────────────────
# Login shells only (ssh, a TTY console, `su -`, `zsh -l`). Debian's
# /etc/zsh/zprofile runs /etc/profile, which ASSIGNS PATH from scratch - after
# ~/.zshenv has already added ~/.local/bin and the mise shims. Without this,
# a login shell loses mise, starship, atuin, carapace and the bat/fd shims.
# .zshenv's PATH blocks are guarded, so re-running it only re-adds what
# /etc/profile removed.

source ~/.zshenv
