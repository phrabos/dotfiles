#!/bin/sh
# waybar custom module: show one interface's IPv4, or the public egress IP.
#
# Port of genmon-ipswitch.sh (XFCE panel) to waybar. Behaviour is the same:
#   left click  -> cycle to the next interface
#   right click -> copy the shown IP to the clipboard
# and a synthetic "public" entry shows the real egress IP. That lookup runs
# ONLY when you cycle onto "public" -- rendering never fetches, so there is no
# background polling. The value is cached and displayed until you cycle onto
# "public" again.
#
# The state file is shared with genmon-ipswitch.sh on purpose, so the XFCE
# panel and waybar always agree on the current selection.
#
# Differences from the genmon version, both forced by Wayland:
#   - output is waybar JSON, not genmon's <txt>/<tool>/<iconclick> XML
#   - clipboard is wl-copy, not xclip (xclip is X11-only and silently no-ops)
#
# Usage: waybar-ipswitch.sh         -> emit waybar JSON (the exec target)
#        waybar-ipswitch.sh cycle   -> advance selection (bound to on-click)
#        waybar-ipswitch.sh copy    -> copy shown IP  (bound to on-click-right)

STATE="${XDG_CONFIG_HOME:-$HOME/.config}/genmon-ipswitch.iface"
PUB_CACHE="${XDG_RUNTIME_DIR:-/tmp}/genmon-pubip.cache"
action="$1"

# Real interfaces that currently have an IPv4, excluding loopback, de-duped.
ifaces="$(ip -o -4 addr show up 2>/dev/null | awk '$2 != "lo" {print $2}' | awk '!seen[$0]++')"
choices="$ifaces public"

fetch_public_ip() {
    ip="$(curl -fsS --max-time 4 https://icanhazip.com 2>/dev/null | tr -d '[:space:]')"
    [ -z "$ip" ] && ip="$(curl -fsS --max-time 4 https://ifconfig.me 2>/dev/null | tr -d '[:space:]')"
    [ -n "$ip" ] && printf '%s' "$ip" > "$PUB_CACHE"
}

# Resolve the current selection, falling back the same way genmon did:
# saved value if still valid -> default-route interface -> first interface.
resolve_sel() {
    sel="$(cat "$STATE" 2>/dev/null)"
    valid=0
    [ "$sel" = "public" ] && valid=1
    for i in $ifaces; do
        [ "$i" = "$sel" ] && valid=1
    done
    if [ "$valid" = "0" ]; then
        sel="$(ip route show default 2>/dev/null | awk '/^default/ {print $5; exit}')"
        [ -z "$sel" ] && sel="$(printf '%s\n' $ifaces | head -n 1)"
    fi
    printf '%s' "$sel"
}

current_ip() {
    if [ "$1" = "public" ]; then
        cat "$PUB_CACHE" 2>/dev/null
    else
        ip -o -4 addr show "$1" 2>/dev/null | awk '{print $4}' | cut -d/ -f1 | head -n 1
    fi
}

case "$action" in
cycle)
    cur="$(cat "$STATE" 2>/dev/null)"
    first=""; next=""; take=0
    for c in $choices; do
        [ -z "$first" ] && first="$c"
        if [ "$take" = "1" ]; then next="$c"; break; fi
        [ "$c" = "$cur" ] && take=1
    done
    [ -z "$next" ] && next="$first"
    if [ -n "$next" ]; then
        printf '%s\n' "$next" > "$STATE"
        [ "$next" = "public" ] && fetch_public_ip
    fi
    exit 0
    ;;
copy)
    sel="$(resolve_sel)"
    ip="$(current_ip "$sel")"
    [ -z "$ip" ] && exit 0
    if command -v wl-copy >/dev/null 2>&1; then
        printf '%s' "$ip" | wl-copy
    elif command -v xclip >/dev/null 2>&1; then
        printf '%s' "$ip" | xclip -selection clipboard
    fi
    exit 0
    ;;
esac

# ─── render ───────────────────────────────────────────────────────────────────

sel="$(resolve_sel)"
if [ "$sel" = "public" ]; then
    label="wan"
else
    label="$sel"
fi
ip="$(current_ip "$sel")"

# class drives the CSS: tun* is a live VPN/lab link, wan is the public egress.
case "$sel" in
    tun*|wg*) class="vpn" ;;
    public)   class="wan" ;;
    *)        class="lan" ;;
esac

if [ -z "$ip" ]; then
    [ "$sel" = "public" ] && ip="?" || ip="no ip"
    class="down"
fi

# waybar JSON. Tooltip newlines must be escaped as \n inside the string.
printf '{"text":"%s %s","tooltip":"%s: %s\\nLeft click: switch interface\\nRight click: copy IP","class":"%s"}\n' \
    "$label" "$ip" "$label" "$ip" "$class"
