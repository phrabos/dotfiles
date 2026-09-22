# ─── PATH ─────────────────────────────────────────────────────────────────────
# ~/.local/bin moved to ~/.zshenv. It was here, login-shell-only, which meant a
# terminal under a Wayland session (Hyprland) never got it: GDM sources
# ~/.profile for X11 sessions but exec's Wayland sessions directly. The .zshenv
# version is guarded, so the original concern -- zellij panes re-prepending on
# every new pane -- cannot happen there either.
