-- Hyprland - Linux counterpart to aerospace/.aerospace.toml
--
-- Lua, not hyprlang. Since Hyprland 0.55 hyprlang is deprecated; 0.56.2 (what
-- Kali ships) still loads a legacy hyprland.conf, but only if no hyprland.lua
-- exists beside it - and it picks once at startup, silently. Keeping both files
-- is the classic trap, so this package ships only the .lua.
--
-- Keybindings mirror the AeroSpace config one-for-one where Hyprland has an
-- equivalent. Divergences are commented inline with the reason.
--
-- Mod key: ALT, matching AeroSpace. On macOS Alt is free because Cmd carries
-- app shortcuts; on Linux Alt is the menu mnemonic key (GTK, Qt, Java/Swing).
-- Burp Suite is Swing, so ALT+F will fullscreen instead of opening Burp's File
-- menu. Change mainMod to "SUPER" to hand Alt back to applications.

local mainMod = "ALT"

local terminal = "ghostty"

-- hyprlauncher rather than wofi: it is the first-party launcher and what the
-- shipped example config uses. It is always a daemon - `-d` starts it without
-- opening a window (see autostart below), `-t` toggles it. Flags confirmed
-- against the binary's own usage strings.
local menu     = "hyprlauncher -t"

------------------
---- MONITORS ----
------------------

-- nwg-displays is the GUI for arranging outputs. It writes hyprlang
-- `monitor = NAME,MODE,POSITION,SCALE` lines to ~/.config/hypr/monitors.conf
-- and its docs tell you to add `source = ...` to your config -- but `source`
-- is hyprlang syntax and does not exist in the Lua config, so that file would
-- be written and then silently ignored. This reads it and replays each line
-- through hl.monitor() instead.
--
-- Hyprland must be allowed to autoreload (it is) so nwg-displays' changes
-- apply without a manual reload.
local function load_nwg_monitors()
    local path = (os.getenv("HOME") or "") .. "/.config/hypr/monitors.conf"
    local fh = io.open(path, "r")
    if not fh then return false end

    local applied = false
    for line in fh:lines() do
        local spec = line:match("^%s*monitor%s*=%s*(.+)$")
        if spec then
            local f = {}
            for part in spec:gmatch("[^,]+") do
                f[#f + 1] = part:match("^%s*(.-)%s*$")
            end
            if f[1] then
                if f[2] == "disable" then
                    hl.monitor({ output = f[1], disabled = true })
                else
                    hl.monitor({
                        output   = f[1],
                        mode     = f[2] or "preferred",
                        position = f[3] or "auto",
                        scale    = f[4] or "auto",
                    })
                end
                applied = true
            end
        end
    end
    fh:close()
    return applied
end

-- The desk: two rows. ASUS 4K is the main screen, top middle; the HP stands
-- in portrait to its right, bottom edges aligned; the laptop sits centred
-- below the ASUS. Positions are in logical (scaled, rotated) pixels:
--
--              x=0          3072  4152
--   y=0                      +----+
--   y=192     +-------------+|    |
--             |    ASUS     || HP |  ASUS 3840x2160 @1.25 -> 3072x1728
--             | 3072 x 1728 ||1080|  HP   1920x1080 rotated -> 1080x1920
--   y=1920    +--+-------+--++----+
--                | laptop|           laptop 1920x1080 at x=576 (centred)
--   y=3000       +-------+
--
-- 1.25 rather than the 1.5 Hyprland picks for a 28" 4K: 1.5 read too large.
-- A scale must divide the mode into whole pixels; 1.25 does (3072x1728).
-- Shifted down 192 so no coordinate is negative (XWayland apps such as Burp
-- mis-place menus on negative outputs). External screens are matched by
-- description, not port, so they keep their place whichever port or dock
-- they come in on; desc: is a prefix match, so serials stay out of the repo.
local monitors = {
    asus   = "desc:ASUSTek COMPUTER INC ASUS VG289Q1A",
    hp     = "desc:HP Inc. HP VH240a",
    laptop = "eDP-1",
}

hl.monitor({ output = monitors.asus, mode = "preferred", position = "0x192",  scale = 1.25 })
-- transform 1 = 90 degrees counter-clockwise (wl_output's direction), for
-- the HP's portrait mount. 3 is the other way round.
hl.monitor({ output = monitors.hp,   mode = "preferred", position = "3072x0", scale = 1, transform = 1 })

-- Lid: while external screens are attached, logind ignores the lid
-- (HandleLidSwitchDocked=ignore, system/), so Hyprland handles it - closing
-- it switches the panel off and its workspaces move to the external screens.
-- The config decides at load time, from the lid's real state; the lid binds
-- (under KEYBINDINGS) just reload it. A reload is the only way back on - a
-- runtime hl.monitor() enabling a disabled output does nothing on 0.56.2,
-- while disabling one works. One code path for both directions.
local function lid_closed()
    local fh = io.open("/proc/acpi/button/lid/LID/state", "r")
    if not fh then return false end
    local state = fh:read("*a") or ""
    fh:close()
    return state:find("closed", 1, true) ~= nil
end

local function laptop_panel(on)
    if on then
        hl.monitor({ output = monitors.laptop, mode = "1920x1080@60", position = "576x1920", scale = 1 })
    else
        hl.monitor({ output = monitors.laptop, disabled = true })
    end
end

local function external_count()
    local n = 0
    for _, m in ipairs(hl.get_monitors()) do
        if m.name ~= monitors.laptop then n = n + 1 end
    end
    return n
end

laptop_panel(not (lid_closed() and external_count() > 0))

-- Anything else (a projector, a hotel TV) lights up to the right at its
-- preferred mode.
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = "auto" })

-- Applied last so a monitors.conf written by nwg-displays can still
-- override the above for a one-off setup. It names ports, not descriptions.
load_nwg_monitors()

-------------------------------
---- ENVIRONMENT VARIABLES ----
-------------------------------

-- ~/.local/bin for everything Hyprland spawns that is NOT a shell: waybar
-- custom modules, scripts on keybinds, apps launched from hyprlauncher. Shells
-- get it from ~/.zshenv; these never read a shell rc at all. GDM sources
-- ~/.profile for X11 sessions but exec's Wayland sessions directly, so the
-- session PATH arrives here without it.
--
-- mise's shims directory goes on too, for the same reason: tools installed
-- through mise (satty, behind screenshot-wl -a) are otherwise invisible to
-- keybinds. Same order as ~/.zshenv: ~/.local/bin ahead of the shims. Each
-- dir is prepended in turn, so the one listed last ends up first.
local _home = os.getenv("HOME")
local _path = os.getenv("PATH") or ""
if _home then
    for _, dir in ipairs({ _home .. "/.local/share/mise/shims", _home .. "/.local/bin" }) do
        if not (":" .. _path .. ":"):find(":" .. dir .. ":", 1, true) then
            _path = dir .. ":" .. _path
        end
    end
    hl.env("PATH", _path)
end

-- Cursor: Catppuccin Mocha, mauve accent, to match everything else rather than
-- XFCE's Adwaita. Installed to ~/.local/share/icons from catppuccin/cursors
-- v2.0.0. That package ships a native hyprcursors/ directory alongside the
-- XCursor one, so HYPRCURSOR_THEME gets the sharper vector version for Wayland
-- clients while XCURSOR_THEME covers XWayland (Burp).
hl.env("HYPRCURSOR_THEME", "catppuccin-mocha-mauve-cursors")
hl.env("HYPRCURSOR_SIZE", "24")
hl.env("XCURSOR_THEME", "catppuccin-mocha-mauve-cursors")
hl.env("XCURSOR_SIZE", "24")
-- qt6ct, not qt5ct: xdg-desktop-portal-hyprland is a Qt6 app. Both qt5ct and
-- qt6ct are already installed here, so this costs nothing either way.
hl.env("QT_QPA_PLATFORMTHEME", "qt6ct")

-- Java/Swing apps (Burp Suite) render as blank grey windows under a
-- non-reparenting WM without this. Applies via XWayland.
hl.env("_JAVA_AWT_WM_NONREPARENTING", "1")

-------------------
---- AUTOSTART ----
-------------------

hl.on("hyprland.start", function()
    -- Publish this session's real values to the systemd/D-Bus activation
    -- environment. GDM does this for X11 via
    -- /etc/X11/Xsession.d/95dbus_update-activation-env; Wayland sessions get
    -- no such wrapper. It matters more here because lingering is enabled, so
    -- the user manager survives logout still carrying the PREVIOUS session's
    -- values -- leaving XDG_SESSION_TYPE=x11 and DESKTOP_SESSION=xfce behind
    -- for anything D-Bus-activated, xdg-desktop-portal included.
    hl.exec_cmd("dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP HYPRLAND_INSTANCE_SIGNATURE DISPLAY")
    hl.exec_cmd("systemctl --user set-environment XDG_SESSION_TYPE=wayland DESKTOP_SESSION=hyprland GDMSESSION=hyprland")

    hl.exec_cmd("waybar")
    hl.exec_cmd("hyprpaper")
    -- Start the launcher daemon without showing it; ALT+D toggles it.
    hl.exec_cmd("hyprlauncher -d")
    -- Vicinae server; SUPER+Space toggles its window. Installed from the
    -- official AppImage into ~/.local/opt/vicinae (not packaged in Kali).
    hl.exec_cmd("vicinae server")
    -- Cmd+Tab-style window switcher overlay; binds SUPER+Tab itself. Installed
    -- from the GitHub release tarball to ~/.local/bin (not packaged in Kali).
    hl.exec_cmd("hyprshell run")
    -- Notifications: swaync (popups plus a control-center panel, SUPER+N).
    -- Started explicitly rather than left to D-Bus activation: swaync and
    -- xfce4-notifyd (installed with XFCE) both ship a service file for
    -- org.freedesktop.Notifications, and with two providers for one bus name
    -- which one D-Bus activates is not deterministic. Starting swaync here
    -- makes it own the name in this session and leaves XFCE's notifyd alone.
    -- Launched directly, not via its systemd unit: that unit is PartOf
    -- graphical-session.target, which this session never starts, and a
    -- direct launch inherits this session's WAYLAND_DISPLAY and PATH.
    hl.exec_cmd("swaync")
    -- Polkit agent (the password dialog for privileged actions):
    -- hyprpolkitagent, Hyprland's own, replacing the MATE agent. It is a Qt 6
    -- app, so it takes the Catppuccin palette from qt6ct. Debian ships it in
    -- /usr/libexec.
    hl.exec_cmd("/usr/libexec/hyprpolkitagent")
    -- On-screen display for the volume / brightness / media keys below.
    hl.exec_cmd("swayosd-server")
    hl.exec_cmd("wl-paste --type text --watch cliphist store")

    -- Idle daemon: lock before suspend, screen back on after resume. See
    -- hypridle.conf - it is deliberately minimal to match XFCE.
    hl.exec_cmd("hypridle")

    -- Bluetooth pairing agent (PIN prompts); blueman-manager also needs it
    -- running. Its tray icon is hidden - waybar's bluetooth module replaces
    -- it - with blueman's plugin list:
    --   gsettings set org.blueman.general plugin-list "['!StatusNotifierItem']"
    -- "!StatusIcon" looks like the obvious key but is ignored on blueman
    -- 2.4.4: StatusIcon depends on non-unloadable plugins, so it can't be
    -- disabled. Dropping the SNI implementation leaves only the XEmbed
    -- GtkStatusIcon, which draws nothing under Wayland but still shows in
    -- XFCE's panel. Undo: `gsettings reset org.blueman.general plugin-list`.
    --
    -- No nm-applet: it only duplicated waybar's network module in the tray.
    -- The network module opens nmtui instead, which prompts for wifi
    -- passwords itself, and VPNs here are started outside NetworkManager.
    hl.exec_cmd("blueman-applet")
end)

-----------------------
---- LOOK AND FEEL ----
-----------------------

-- Gaps from [gaps] in .aerospace.toml (inner 8 / outer 8). Colors are
-- Catppuccin Mocha with a mauve accent, matching starship's
-- catppuccin-mocha-mauve palette and ghostty's theme.
hl.config({
    general = {
        gaps_in  = 4,   -- 4 per edge = 8 between windows, as AeroSpace inner 8
        gaps_out = 8,

        border_size = 2,

        -- Focused window: mauve -> pink at 45deg, the same pair as the lock
        -- screen clock, so the two accents recur across the desktop. A
        -- static angle - the "loop" borderangle style re-renders every
        -- frame forever (wiki warning), which costs battery.
        col = {
            active_border   = { colors = { "rgba(cba6f7ff)", "rgba(f5c2e7ff)" }, angle = 45 }, -- mauve, pink
            inactive_border = "rgba(45475aff)", -- surface1
        },

        resize_on_border = true,
        layout           = "dwindle",
    },

    decoration = {
        -- 12, up from 8, so the squircle curve below has room to show; at
        -- 8 it was indistinguishable from a plain arc.
        rounding = 12,
        -- Squircle corners: the corner curve is a superellipse with this
        -- exponent. 2.0 (the default) is a circular arc; higher values
        -- square it off with a smoother start into the straight edge.
        -- 2.5 as in end-4's dots.
        rounding_power = 2.5,

        -- Dim unfocused windows so the focused one stands out alongside its
        -- gradient border. 0.15, not the default 0.5, which reads as
        -- "disabled" rather than "not focused". The fade between states
        -- follows the fade animation (fadeDim inherits it).
        dim_inactive = true,
        dim_strength = 0.15,

        -- ghostty runs at background-opacity 0.8 with blur; matching the
        -- compositor blur keeps it looking as it does on macOS.
        blur = {
            enabled = true,
            size    = 6,
            passes  = 2,
        },

        shadow = {
            enabled = true,
            range   = 12,
            color   = 0xaa11111b, -- crust
        },

        -- Glow (new in 0.56): a soft halo on the focused window only, in the
        -- border's mauve -> pink pair so the accent carries past the 2px
        -- line. range 15 with render_power 2 (slower falloff) so the halo
        -- reaches visibly past the shadow; 0x99 alpha keeps it light, not a
        -- second border. color_inactive defaults to opaque white, so it is
        -- zeroed out.
        glow = {
            enabled        = true,
            range          = 15,
            render_power   = 2,
            color          = { colors = { "rgba(cba6f799)", "rgba(f5c2e799)" }, angle = 45 }, -- mauve, pink
            color_inactive = "rgba(00000000)",
        },
    },

    -- Tabbed groups (ALT+A). Hyprland's defaults are translucent yellow
    -- borders and orange for locked groups; these follow the window borders
    -- instead, with the tab bar in the same mauve / surface pair as waybar's
    -- workspace buttons. Locked groups get peach so they still read as
    -- different.
    group = {
        col = {
            border_active          = { colors = { "rgba(cba6f7ff)", "rgba(f5c2e7ff)" }, angle = 45 },
            border_inactive        = "rgba(45475aff)",
            border_locked_active   = "rgba(fab387ff)", -- peach
            border_locked_inactive = "rgba(fab38766)",
        },
        groupbar = {
            font_family          = "IosevkaTerm Nerd Font Propo",
            font_size            = 11,
            height               = 18,
            gradients            = true,
            rounding             = 8,
            indicator_height     = 0,
            text_color           = "rgba(1e1e2eff)", -- base, on the mauve tab
            text_color_inactive  = "rgba(cdd6f4ff)", -- text
            col = {
                active          = "rgba(cba6f7ff)",
                inactive        = "rgba(313244ff)", -- surface0
                locked_active   = "rgba(fab387ff)",
                locked_inactive = "rgba(313244ff)",
            },
        },
    },

    -- Note: there is no dwindle.pseudotile setting - pseudotiling is a
    -- dispatcher (hl.dsp.window.pseudo) and a window-rule effect, not a
    -- layout option. Verified against /usr/share/hypr/stubs/hl.meta.lua.
    dwindle = {
        preserve_split = true,
    },

    misc = {
        disable_hyprland_logo   = true,
        disable_splash_rendering = true,
        focus_on_activate       = true,
    },

    input = {
        kb_layout  = "us",
        kb_options = "caps:escape", -- matches the X11 setxkbmap option

        follow_mouse = 1,
        sensitivity  = 0,

        -- XFCE sets /Default/KeyRepeat/Rate = 62 (repeats per second).
        -- Hyprland's default is 25, which is why typing felt sluggish.
        -- Delay is unset on the XFCE side, so both sit on their own default
        -- (XFCE ~500ms vs Hyprland 600ms) - pinned here so they agree.
        repeat_rate  = 62,
        repeat_delay = 500,

        touchpad = {
            -- false to match XFCE on this machine, which leaves libinput's
            -- Natural_Scrolling property unset and so defaults to off. macOS
            -- defaults the other way; flip this to true if it's the Mac you
            -- want to match instead.
            natural_scroll       = false,
            disable_while_typing = true,

            -- XFCE sets libinput_Click_Method_Enabled = [0,1] on both
            -- touchpads. That array is [button-areas, clickfinger], so
            -- button-areas is off and clickfinger is on: two fingers = right
            -- click, three = middle, anywhere on the pad. Hyprland defaults to
            -- button-areas, where right click means the bottom-right corner.
            -- This is the setting that felt different.
            clickfinger_behavior = true,
        },
    },
})

hl.config({ animations = { enabled = true } })

-- Animations. speed is in deciseconds (4 = 400ms). Leaves inherit from their
-- parent, so only the ones that should differ are set. Tree and styles:
-- https://wiki.hypr.land/Configuring/Animations/
hl.curve("smooth", { type = "bezier", points = { { 0.05, 0.9 }, { 0.1, 1.0 } } })
hl.curve("ease",   { type = "bezier", points = { { 0.25, 0.1 }, { 0.25, 1.0 } } })

-- Windows grow in from 85% and shrink out, rather than the default slide.
hl.animation({ leaf = "windows",     enabled = true, speed = 4, bezier = "smooth", style = "popin 85%" })
hl.animation({ leaf = "windowsOut",  enabled = true, speed = 3, bezier = "smooth", style = "popin 85%" })
hl.animation({ leaf = "windowsMove", enabled = true, speed = 4, bezier = "smooth" })

-- Layers: waybar, the swaync panel, Vicinae, hyprlauncher, hyprshell. A
-- fade rather than a slide - swaync animates its own popups, and a
-- compositor slide on top of that doubles up.
hl.animation({ leaf = "layers",      enabled = true, speed = 3, bezier = "ease", style = "fade" })

hl.animation({ leaf = "fade",        enabled = true, speed = 4, bezier = "smooth" })
-- Menus and tooltips (Wayland popups) should feel instant.
hl.animation({ leaf = "fadePopups",  enabled = true, speed = 2, bezier = "ease" })

-- Border colour cross-fades as focus moves, instead of snapping.
hl.animation({ leaf = "border",      enabled = true, speed = 5, bezier = "ease" })

-- Workspaces slide with a fade, over 15% of the screen rather than all of it.
hl.animation({ leaf = "workspaces",  enabled = true, speed = 4, bezier = "smooth", style = "slidefade 15%" })
-- Special workspaces (the SUPER+5 Obsidian dropdown) slide down over the
-- current workspace instead of sideways like a workspace switch.
hl.animation({ leaf = "specialWorkspace", enabled = true, speed = 4, bezier = "smooth", style = "slidevert" })

---------------------
---- KEYBINDINGS ----
---------------------

-- Every bind goes through this wrapper so it carries a description. Lua binds
-- show up in `hyprctl binds` as dispatcher "__lua" with an opaque arg, so the
-- description is the only human-readable thing left - and it is what the
-- SUPER+K cheat sheet (~/.local/bin/hypr-keybinds) lists.
local function bind(keys, desc, dispatcher, opts)
    opts = opts or {}
    opts.description = desc
    return hl.bind(keys, dispatcher, opts)
end

-- Launchers. No AeroSpace equivalent - macOS uses Spotlight/Raycast.
bind(mainMod .. " + Return", "Terminal", hl.dsp.exec_cmd(terminal))
bind(mainMod .. " + D",      "App launcher (hyprlauncher) - Esc or ALT+D closes", hl.dsp.exec_cmd(menu))
-- SUPER+Space is Cmd+Space: Vicinae, a Spotlight/Raycast-style search over
-- apps, files, calculator and clipboard history (see vicinae/ in dotfiles).
-- The server is started in autostart; this only toggles its window. ALT+D
-- keeps the plain hyprlauncher as a fallback.
bind("SUPER + space",        "Search (Spotlight-style, Vicinae) - Esc or SUPER+Space closes", hl.dsp.exec_cmd("vicinae toggle"))

-- Focus, vim keys. Safe alongside Zellij: it uses "Super Alt <arrow>" for pane
-- focus, not alt-hjkl.
bind(mainMod .. " + H", "Focus left",  hl.dsp.focus({ direction = "left" }))
bind(mainMod .. " + J", "Focus down",  hl.dsp.focus({ direction = "down" }))
bind(mainMod .. " + K", "Focus up",    hl.dsp.focus({ direction = "up" }))
bind(mainMod .. " + L", "Focus right", hl.dsp.focus({ direction = "right" }))

-- Move windows.
bind(mainMod .. " + SHIFT + H", "Move window left",  hl.dsp.window.move({ direction = "left" }))
bind(mainMod .. " + SHIFT + J", "Move window down",  hl.dsp.window.move({ direction = "down" }))
bind(mainMod .. " + SHIFT + K", "Move window up",    hl.dsp.window.move({ direction = "up" }))
bind(mainMod .. " + SHIFT + L", "Move window right", hl.dsp.window.move({ direction = "right" }))

-- Split orientation. Imperfect mapping: AeroSpace sets an explicit orientation
-- for the next split, dwindle only toggles the current one. AeroSpace's
-- alt-s is therefore dropped rather than bound to the same toggle as alt-v.
bind(mainMod .. " + V", "Toggle split orientation", hl.dsp.layout("togglesplit"))

-- Layout.
bind(mainMod .. " + F",             "Toggle fullscreen", hl.dsp.window.fullscreen({ mode = "fullscreen", action = "toggle" }))
bind(mainMod .. " + SHIFT + space", "Toggle floating",   hl.dsp.window.float({ action = "toggle" }))

-- AeroSpace 'layout accordion'. Hyprland's closest analog is a tabbed group -
-- windows stack in one frame with a tab bar. There is no separate 'tiles'
-- primitive to bind alt-t to, so only alt-a survives.
bind(mainMod .. " + A",            "Toggle tabbed group",  hl.dsp.group.toggle())
bind(mainMod .. " + bracketleft",  "Previous tab in group", hl.dsp.group.prev())
bind(mainMod .. " + bracketright", "Next tab in group",     hl.dsp.group.next())

-- Close. Windows only: the launchers (ALT+D, SUPER+Space) are layer-shell
-- overlays, not windows, so this skips them - close those with Escape or
-- their own key again.
bind(mainMod .. " + SHIFT + Q", "Close window (launchers: Esc)", hl.dsp.window.close())

-- Blackhole (workspace 7) has no dedicated bind any more: ALT+M and
-- ALT+SHIFT+M were dropped so both reach applications (Zellij's "Alt m" is
-- SwitchToMode Move). ALT+SHIFT+7 from the loop below still sends a window
-- there.

-- Defined with the Obsidian dropdown further down; ALT+5 calls it first so
-- workspace 5 never comes up empty while Obsidian is borrowed.
local notes_send_home

-- Workspaces. The nine near-identical bind pairs from .aerospace.toml collapse
-- into a loop - one of the reasons the Lua config is worth the migration.
for i = 1, 10 do
    local key = i % 10 -- workspace 10 sits on the "0" key, as AeroSpace's 0
    if i == 5 then
        bind(mainMod .. " + 5", "Go to workspace 5 (brings Obsidian back from the dropdown)", function()
            notes_send_home()
            hl.dispatch(hl.dsp.focus({ workspace = 5 }))
        end)
    else
        bind(mainMod .. " + " .. key,     "Go to workspace " .. i,        hl.dsp.focus({ workspace = i }))
    end
    bind(mainMod .. " + SHIFT + " .. key, "Move window to workspace " .. i, hl.dsp.window.move({ workspace = i }))
end

-- Back and forth.
bind(mainMod .. " + Tab", "Previous workspace (back and forth)", hl.dsp.focus({ last = true }))

-- Reload. Hyprland reloads on save; this forces it.
bind(mainMod .. " + SHIFT + R", "Reload Hyprland config", hl.dsp.exec_cmd("hyprctl reload"))

-- Modes. AeroSpace's service mode is dropped: its only binding was reload,
-- which ALT+SHIFT+R above already does directly.
bind(mainMod .. " + R", "Resize mode (hjkl, Esc to leave)", hl.dsp.submap("resize"))

-- Mouse. Hold ALT, then left-drag anywhere on a window to move it, or
-- right-drag to resize it from the nearest corner. Borders are also
-- draggable (resize_on_border above).
bind(mainMod .. " + mouse:272", "Drag to move window",   hl.dsp.window.drag(),   { mouse = true })
bind(mainMod .. " + mouse:273", "Drag to resize window", hl.dsp.window.resize(), { mouse = true })

-- Media and brightness keys. No AeroSpace equivalent - macOS handles these in
-- the OS, so there was nothing to port and I originally left them out.
--   locked    = still work when hyprlock has the screen
--   repeating = hold the key to keep stepping
--
-- All through swayosd-client, which makes the change AND shows the themed
-- popup (~/.config/swayosd/). Volume steps 5% and is capped at 100% by the
-- server's max_volume, as the old `wpctl -l 1` was. Brightness keeps a 5%
-- floor (min_brightness) so it never reaches black.
bind("XF86AudioRaiseVolume",  "Volume up",       hl.dsp.exec_cmd("swayosd-client --output-volume +5"),        { locked = true, repeating = true })
bind("XF86AudioLowerVolume",  "Volume down",     hl.dsp.exec_cmd("swayosd-client --output-volume -5"),        { locked = true, repeating = true })
bind("XF86AudioMute",         "Mute",            hl.dsp.exec_cmd("swayosd-client --output-volume mute-toggle"), { locked = true })
bind("XF86AudioMicMute",      "Mute microphone", hl.dsp.exec_cmd("swayosd-client --input-volume mute-toggle"),  { locked = true })

-- intel_backlight is writable by the video group, which this user is in, so
-- SwayOSD needs no extra udev setup here.
bind("XF86MonBrightnessUp",   "Brightness up",   hl.dsp.exec_cmd("swayosd-client --brightness +5"), { locked = true, repeating = true })
bind("XF86MonBrightnessDown", "Brightness down", hl.dsp.exec_cmd("swayosd-client --brightness -5"), { locked = true, repeating = true })

-- Media transport. Play and Pause are separate keysyms; both go to
-- play-pause so whichever your keyboard emits behaves the same. The popup
-- shows "artist - title" (playerctl_format in the SwayOSD config).
bind("XF86AudioPlay",  "Play/pause",     hl.dsp.exec_cmd("swayosd-client --playerctl play-pause"), { locked = true })
bind("XF86AudioPause", "Play/pause",     hl.dsp.exec_cmd("swayosd-client --playerctl play-pause"), { locked = true })
bind("XF86AudioNext",  "Next track",     hl.dsp.exec_cmd("swayosd-client --playerctl next"),       { locked = true })
bind("XF86AudioPrev",  "Previous track", hl.dsp.exec_cmd("swayosd-client --playerctl prev"),       { locked = true })

--------------------------------------------
---- XFCE PARITY: SUPER / CTRL+ALT BINDS ----
--------------------------------------------
-- These mirror xfce4-keyboard-shortcuts one-for-one, so the muscle memory you
-- already have keeps working. They use SUPER and CTRL+ALT, which are entirely
-- free here because mainMod is ALT - nothing collides with the AeroSpace
-- bindings above.

-- One key per action. The XFCE set had several aliases for each of these
-- (Super+R / Alt+F2 / Alt+F1 / Ctrl+Esc all opened a launcher, and so on);
-- only one of each survives here.

-- Lock screen (was xflock4). loginctl rather than calling hyprlock directly,
-- so hypridle's before_sleep_cmd and this bind go through the same path.
bind("SUPER + L", "Lock screen", hl.dsp.exec_cmd("loginctl lock-session"))

-- Power menu: lock / suspend / hibernate / log out / reboot / shut down (see
-- ~/.local/bin/power-menu). Replaces the xfce4-session-logout dialog; also on
-- the waybar power chip and the swaync power button.
--
-- The physical power button opens it too, as Omarchy's does. That needs
-- logind to leave the key alone - HandlePowerKey=ignore in
-- system/logind.conf.d/ - otherwise logind powers off before Hyprland sees
-- the key. Only affects a running system: from off or hibernated, the button
-- is the firmware's and powers on as usual; holding it still forces off.
bind("CTRL + ALT + Delete", "Power menu", hl.dsp.exec_cmd("power-menu"))
bind("XF86PowerOff",        "Power menu", hl.dsp.exec_cmd("power-menu"))

-- Lid, while external screens are attached (see MONITORS): closed switches
-- the laptop panel off, and Hyprland moves its workspaces (10, Keymapp) to
-- an external screen; open brings the panel back and rehome_workspaces()
-- returns them. With no external screen the lid is left to logind (suspend
-- on battery, nothing on AC). locked = works on the lock screen too.
-- Both reload; MONITORS reads the lid state. Deferred a moment so the
-- /proc lid state has caught up with the switch event.
local function reload_for_lid()
    hl.timer(function() hl.dispatch(hl.dsp.reload_config()) end, { timeout = 300, type = "oneshot" })
end
bind("switch:on:Lid Switch",  "Lid closed: laptop panel off (docked only)", reload_for_lid, { locked = true })
bind("switch:off:Lid Switch", "Lid opened: laptop panel on",                reload_for_lid, { locked = true })

-- xkill equivalent: the next window you click is killed; Escape backs out. For
-- a hung window that ignores ALT+SHIFT+Q (a polite close request). Killing
-- Ghostty takes every Ghostty window with it (one process); Zellij sessions
-- survive.
--
-- Built on the "kill" submap below rather than `hyprctl kill`: on 0.56.2 that
-- command returns but never actually arms click-to-kill.
bind("CTRL + ALT + Escape", "Kill mode: click a window to kill it", function()
    hl.exec_cmd([[notify-send -t 30000 "Kill mode" "Click a window to kill it - Escape to cancel"]])
    hl.dispatch(hl.dsp.submap("kill"))
    -- Don't leave every other bind disabled if the mode is forgotten.
    hl.timer(function()
        if hl.get_current_submap() == "kill" then
            hl.dispatch(hl.dsp.submap("reset"))
        end
    end, { timeout = 30000, type = "oneshot" })
end)

-- File manager (was exo-open --launch FileManager)
bind("SUPER + E", "File manager", hl.dsp.exec_cmd("thunar"))

-- Web browser (was exo-open --launch WebBrowser; helpers.rc says firefox)
bind("SUPER + W", "Web browser", hl.dsp.exec_cmd("firefox"))

-- Wallpaper picker: lists ~/Pictures/wallpapers in Vicinae, applies the choice
-- over hyprpaper IPC and writes it into hyprpaper.conf. See
-- ~/.local/bin/wallpaper (it also takes a filename, or --random).
bind("SUPER + SHIFT + W", "Wallpaper picker", hl.dsp.exec_cmd("wallpaper"))

-- Display arrangement (was xfce4-display-settings on Super+P / XF86Display).
bind("SUPER + P", "Display settings", hl.dsp.exec_cmd("nwg-displays"))

-- Clipboard history: Vicinae's, which records on its own, previews images and
-- pastes straight into the previous window. toggle=true makes the same key
-- close it. On SUPER+CTRL+V, as in Omarchy, because SUPER+V is universal
-- paste below. cliphist still records in autostart as a fallback history:
--   cliphist list | hyprlauncher -m | cliphist decode | wl-copy
bind("SUPER + CTRL + V", "Clipboard history (Vicinae)", hl.dsp.exec_cmd("vicinae deeplink 'vicinae://launch/clipboard/history?toggle=true'"))

-- Screenshots, on the macOS shape rather than the Print cluster: SUPER+SHIFT
-- plus 3 / 4 / 5 for full / region / window, mirroring Cmd+Shift+3 and
-- Cmd+Shift+4. Adding CTRL copies to the clipboard instead of saving.
-- Shifted digits arrive as their symbol keysyms, which is why these read
-- numbersign / dollar / percent - the same form your XFCE binding used.
--
-- screenshot-wl saves to ~/Pictures/sh with the same filename format the XFCE
-- script used, so both desktops land in one pile. If
-- ecosystem.enforce_permissions is ever turned on, grim needs an explicit
-- hl.permission entry for "screencopy".
bind("SUPER + SHIFT + numbersign",        "Screenshot: full screen",            hl.dsp.exec_cmd("screenshot-wl full"))
bind("CTRL + SUPER + SHIFT + numbersign", "Screenshot: full screen to clipboard", hl.dsp.exec_cmd("screenshot-wl full -c"))
bind("SUPER + SHIFT + dollar",            "Screenshot: region",                 hl.dsp.exec_cmd("screenshot-wl region"))
bind("CTRL + SUPER + SHIFT + dollar",     "Screenshot: region to clipboard",    hl.dsp.exec_cmd("screenshot-wl region -c"))
bind("SUPER + SHIFT + percent",           "Screenshot: window",                 hl.dsp.exec_cmd("screenshot-wl window"))
bind("CTRL + SUPER + SHIFT + percent",    "Screenshot: window to clipboard",    hl.dsp.exec_cmd("screenshot-wl window -c"))

-- Region into swappy for crop/markup; swappy owns save and copy from there.
bind("SUPER + SHIFT + A", "Screenshot: region into swappy (annotate)", hl.dsp.exec_cmd("screenshot-wl region -a"))

-- App switcher: SUPER+Tab, the macOS Cmd+Tab shape, with an overlay. Handled
-- by hyprshell (autostarted above), which registers its own binds at runtime -
-- config lives in ~/.config/hyprshell/config.toml, not here.

-- Notifications (swaync). The panel holds history, Do Not Disturb, media,
-- volume/brightness and quick toggles; the waybar bell opens it too.
bind("SUPER + N",         "Notification panel",                hl.dsp.exec_cmd("swaync-client -t -sw"))
bind("SUPER + SHIFT + N", "Toggle Do Not Disturb",             hl.dsp.exec_cmd("swaync-client -d -sw"))
bind("SUPER + CTRL + N",  "Dismiss newest notification popup", hl.dsp.exec_cmd("swaync-client --close-latest -sw"))

-- Keybinding cheat sheet, as Omarchy's SUPER+K. Lists every bind above by its
-- description; see ~/.local/bin/hypr-keybinds.
bind("SUPER + K", "Keybinding cheat sheet", hl.dsp.exec_cmd("hypr-keybinds"))

-- Transparency on/off for the focused window, as Omarchy's SUPER+Backspace.
-- Omarchy toggles the "opaque" prop, but that can only force a window solid -
-- it works there because Omarchy gives every window a default opacity below 1.
-- Windows here are opaque by default, so this toggles the "opacity" prop
-- instead, which works on anything. It fades the whole window, text included,
-- and multiplies with Ghostty's own background-opacity. Per window; state is
-- forgotten when the window closes or the config reloads.
local translucent_opacity = "0.75"

-- set_prop "opacity" is the FOCUSED opacity only; unfocused and fullscreen
-- are their own props. Setting just the one left a toggled window translucent
-- only while focused (and a solid-toggled browser translucent again on focus
-- loss). A window rule's single value covers all three, so this does too.
local function set_window_opacity(sel, value)
    for _, prop in ipairs({ "opacity", "opacity_inactive", "opacity_fullscreen" }) do
        hl.dispatch(hl.dsp.window.set_prop({ window = sel, prop = prop, value = value }))
    end
end
-- Classes that open translucent (the browsers-ws2, obsidian-ws5 and
-- discord-ws8 window rules below apply translucent_opacity to them), so the
-- first press makes them solid.
local translucent_by_default = {
    ["firefox-esr"]   = true,
    ["brave-browser"] = true,
    ["google-chrome"] = true,
    ["md.obsidian.Obsidian"] = true,
    ["obsidian"]             = true,
    ["discord"]              = true,
    ["Discord"]              = true,
}
-- Per-window state once toggled; nil means "still at the class default".
local translucent_windows = {}

bind("SUPER + BackSpace", "Toggle transparency (focused window)", function()
    local window = hl.get_active_window()
    if not window then return end
    local current = translucent_windows[window.address]
    if current == nil then
        current = translucent_by_default[window.class] == true
    end
    local on = not current
    translucent_windows[window.address] = on
    set_window_opacity("address:" .. window.address, on and translucent_opacity or "1")
end)

-- Obsidian dropdown. Obsidian lives tiled on workspace 5; SUPER+5 borrows its
-- one window into the "notes" special workspace (a scratchpad) as a floating
-- panel docked on the right, over whatever workspace is showing. Pressing it
-- again sends the window home to 5, tiled again. One window, so there is no
-- second copy to keep in sync. Solid while dropped down so the page behind
-- doesn't show through the note; its SUPER+Backspace state returns with it.
local notes_special = "notes"
local notes_width   = 0.45 -- share of the monitor width
local obsidian_classes = { ["md.obsidian.Obsidian"] = true, ["obsidian"] = true }
local notes_pending = false -- SUPER+5 launched Obsidian; drop it down on open

local function find_obsidian()
    for _, w in ipairs(hl.get_windows()) do
        if obsidian_classes[w.class] then return w end
    end
end

local function is_dropped(w)
    return w.workspace ~= nil and w.workspace.name == "special:" .. notes_special
end

local function drop_down(w)
    local sel = "address:" .. w.address
    local mon = hl.get_active_monitor()
    -- The panel's inner edge sits where a tiled window's would: inside the
    -- outer gap, the border and waybar's reserved strip. In Lua reserved is
    -- keyed ({ top = 30.0, ... }), not the list hyprctl monitors prints.
    local inset = 8 + 2 -- gaps_out + border_size
    local r = mon.reserved or {}
    local top, bottom = math.floor(r.top or 0), math.floor(r.bottom or 0)
    local w_px = math.floor(mon.width * notes_width)
    local h_px = mon.height - top - bottom - 2 * inset
    hl.dispatch(hl.dsp.window.move({ window = sel, workspace = "special:" .. notes_special, follow = false }))
    hl.dispatch(hl.dsp.window.float({ window = sel, action = "enable" }))
    hl.dispatch(hl.dsp.window.resize({ window = sel, x = w_px, y = h_px }))
    hl.dispatch(hl.dsp.window.move({ window = sel, x = mon.x + mon.width - inset - w_px, y = mon.y + top + inset }))
    set_window_opacity(sel, "1")
    hl.dispatch(hl.dsp.workspace.toggle_special(notes_special))
    hl.dispatch(hl.dsp.focus({ window = sel }))
end

notes_send_home = function()
    local w = find_obsidian()
    if not (w and is_dropped(w)) then return end
    local sel = "address:" .. w.address
    -- Hide the scratchpad first (it slides back up with the window in it).
    -- Moving the window out of a visible special workspace leaves it open
    -- and empty over the current workspace - close_special_on_empty does
    -- not fire for a silent move on 0.56.2.
    local special = hl.get_active_special_workspace()
    if special and special.name == "special:" .. notes_special then
        hl.dispatch(hl.dsp.workspace.toggle_special(notes_special))
    end
    hl.dispatch(hl.dsp.window.move({ window = sel, workspace = 5, follow = false }))
    hl.dispatch(hl.dsp.window.float({ window = sel, action = "disable" }))
    local translucent = translucent_windows[w.address]
    if translucent == nil then translucent = translucent_by_default[w.class] == true end
    set_window_opacity(sel, translucent and translucent_opacity or "1")
end

bind("SUPER + 5", "Obsidian dropdown (docked right; again to send it home to 5)", function()
    local w = find_obsidian()
    if not w then
        notes_pending = true
        hl.exec_cmd("obsidian")
    elseif is_dropped(w) then
        notes_send_home()
    else
        drop_down(w)
    end
end)

hl.on("window.open", function(w)
    if notes_pending and w and obsidian_classes[w.class] then
        notes_pending = false
        drop_down(w)
    end
end)

----------------------------------------
---- macOS PARITY: CMD-STYLE CLIPBOARD ----
----------------------------------------
-- SUPER+C / V / X copy, paste and cut in every app, the way Cmd+C/V/X do on
-- the Mac - the Voyager's GUI key is Cmd there and Super here. Ported from
-- Omarchy Quattro's default/hypr/bindings/clipboard.lua.
--
-- Each press is re-sent to the focused window as the app's own shortcut, with
-- explicit mods so the physically held SUPER does not leak into it. Down and up
-- are sent separately because send_shortcut can leave the key stuck repeating
-- (hyprwm/Hyprland discussion 14099).
--
-- Terminals need something other than Ctrl+C (that is SIGINT). Omarchy sends
-- Ctrl+Insert / Shift+Insert, but Ghostty maps Shift+Insert to
-- paste_from_selection - the PRIMARY selection, not the clipboard - so this
-- uses Ghostty's Ctrl+Shift+C / Ctrl+Shift+V instead.
local terminal_classes = {
    ["com.mitchellh.ghostty"] = true,
}

local function send_once(mods, key)
    hl.dispatch(hl.dsp.send_key_state({ mods = mods, key = key, state = "down" }))
    hl.timer(function()
        hl.dispatch(hl.dsp.send_key_state({ mods = mods, key = key, state = "up" }))
    end, { timeout = 50, type = "oneshot" })
end

local function clipboard_shortcut(key)
    return function()
        local window = hl.get_active_window()
        if window and terminal_classes[window.class] then
            send_once("CTRL SHIFT", key)
        else
            send_once("CTRL", key)
        end
    end
end

bind("SUPER + C", "Copy (Cmd+C)",  clipboard_shortcut("C"))
bind("SUPER + V", "Paste (Cmd+V)", clipboard_shortcut("V"))
-- Terminals have no cut; Ctrl+Shift+X would reach the shell as a keystroke,
-- so there it is a copy.
bind("SUPER + X", "Cut (Cmd+X)", function()
    local window = hl.get_active_window()
    if window and terminal_classes[window.class] then
        send_once("CTRL SHIFT", "C")
    else
        send_once("CTRL", "X")
    end
end)

-- Alt+Backspace deletes a word in GTK apps via the GTK3 binding set, matching
-- macOS Option+Backspace. Electron apps (Obsidian, Discord) ignore GTK key
-- themes, and their editors use Ctrl+Backspace on Linux, so for those the key
-- is translated. The bind is only enabled while one of them is focused, so
-- everywhere else - Ghostty/zsh above all - Alt+Backspace passes through
-- untouched.
local word_delete_classes = {
    ["md.obsidian.Obsidian"] = true,
    ["obsidian"]             = true,
    ["discord"]              = true,
    ["Discord"]              = true,
}

local alt_backspace = bind("ALT + BackSpace", "Delete word (Electron apps)", function()
    send_once("CTRL", "BackSpace")
end, { repeating = true })
local function update_alt_backspace()
    local window = hl.get_active_window()
    alt_backspace:set_enabled(window ~= nil and word_delete_classes[window.class] == true)
end

-- Run once now too, so a config reload with Obsidian focused is right straight
-- away rather than after the next focus change.
update_alt_backspace()
hl.on("window.active", update_alt_backspace)

-- Dropped from the AeroSpace config:
--   alt-y / alt-shift-y   'tv' workspace on the Beyond TV display. No such
--                         display here, and dropping it hands Alt+y back to
--                         Zellij (MoveTab Left), which currently loses it.
--   alt-shift-tab         move-workspace-to-monitor: single display.
--   alt-shift-n / -p      move-node-to-monitor: single display.
--   alt-shift-b           balance-sizes: dwindle has no equivalent, so it is
--                         left unbound rather than mapped to something that
--                         behaves differently.

---------------
---- MODES ----
---------------

-- Mirrors [mode.resize.binding]. relative = true is required: without it
-- resize treats {x, y} as an absolute size, and 50x0 fails with "Invalid size".
hl.define_submap("resize", function()
    bind("H", "Resize: narrower", hl.dsp.window.resize({ x = -50, y = 0,  relative = true }), { repeating = true })
    bind("J", "Resize: taller",   hl.dsp.window.resize({ x = 0,   y = 50,  relative = true }), { repeating = true })
    bind("K", "Resize: shorter",  hl.dsp.window.resize({ x = 0,   y = -50, relative = true }), { repeating = true })
    bind("L", "Resize: wider",    hl.dsp.window.resize({ x = 50,  y = 0,  relative = true }), { repeating = true })

    bind("SHIFT + H", "Resize: much narrower", hl.dsp.window.resize({ x = -200, y = 0,    relative = true }), { repeating = true })
    bind("SHIFT + J", "Resize: much taller",   hl.dsp.window.resize({ x = 0,    y = 200,  relative = true }), { repeating = true })
    bind("SHIFT + K", "Resize: much shorter",  hl.dsp.window.resize({ x = 0,    y = -200, relative = true }), { repeating = true })
    bind("SHIFT + L", "Resize: much wider",    hl.dsp.window.resize({ x = 200,  y = 0,    relative = true }), { repeating = true })

    bind(mainMod .. " + R", "Leave resize mode", hl.dsp.submap("reset"))
    bind("Return",          "Leave resize mode", hl.dsp.submap("reset"))
    bind("Escape",          "Leave resize mode", hl.dsp.submap("reset"))
end)

-- Entered by CTRL+ALT+Escape. follow_mouse = 1 focuses whatever is under the
-- pointer, so on click the focused window is the clicked one.
hl.define_submap("kill", function()
    bind("mouse:272", "Kill the clicked window", function()
        hl.dispatch(hl.dsp.window.kill())
        hl.dispatch(hl.dsp.submap("reset"))
    end)
    bind("Escape", "Cancel kill mode", hl.dsp.submap("reset"))
end)

------------------------
---- WORKSPACE RULES ----
------------------------

-- Keep the AeroSpace-semantic workspaces alive even when empty, so waybar's
-- persistent-workspaces entries have something to bind to. Waybar alone only
-- draws them; they must exist compositor-side too.
--   1 terminal · 2 browsers · 5 Obsidian · 6 security tooling · 7 blackhole
--   8 chat (Discord)
--
-- Each workspace also has a home screen (see MONITORS for the desk). The ASUS
-- is the work screen - terminals, browsers, security tooling and anything
-- unassigned; the HP holds notes and chat beside it; the laptop holds
-- Keymapp's layer map. Apps follow their workspace (window rules below).
-- default = the workspace a screen shows when it first lights up.
-- 10 is persistent too so the laptop's bar always has its "0".
local workspace_homes = {
    { ws = "1",  on = monitors.asus,   persistent = true, default = true }, -- terminal
    { ws = "2",  on = monitors.asus,   persistent = true },                 -- browsers
    { ws = "3",  on = monitors.asus },
    { ws = "4",  on = monitors.asus },
    { ws = "6",  on = monitors.asus,   persistent = true },                 -- Burp, Wireshark
    { ws = "7",  on = monitors.asus,   persistent = true },                 -- blackhole
    { ws = "9",  on = monitors.asus },
    { ws = "5",  on = monitors.hp,     persistent = true, default = true }, -- Obsidian
    { ws = "8",  on = monitors.hp,     persistent = true },                 -- Discord
    { ws = "10", on = monitors.laptop, persistent = true, default = true }, -- Keymapp
}
for _, h in ipairs(workspace_homes) do
    hl.workspace_rule({ workspace = h.ws, monitor = h.on, persistent = h.persistent, default = h.default })
end

-- The rules above only place a workspace when it is created. On unplug,
-- Hyprland itself moves a screen's workspaces to one still connected. On
-- plug-in it only returns those that left the same PORT, and never ones
-- first opened while the screen was away (Ghostty started on the laptop,
-- then the ASUS arrives). So when a screen appears, pull every workspace
-- whose home it is back onto it.
local function monitor_is(m, selector)
    if selector:sub(1, 5) == "desc:" then
        local want = selector:sub(6)
        return (m.description or ""):sub(1, #want) == want
    end
    return m.name == selector
end

local function rehome_workspaces()
    for _, m in ipairs(hl.get_monitors()) do
        for _, h in ipairs(workspace_homes) do
            local ws = hl.get_workspace(h.ws)
            if ws and monitor_is(m, h.on) and not (ws.monitor and ws.monitor.name == m.name) then
                hl.dispatch(hl.dsp.workspace.move({ workspace = h.ws, monitor = m.name }))
            end
        end
    end
end

-- Deferred: monitor.added fires before the new output has finished setting
-- up (and before Hyprland's own returning-workspace pass), and a reload
-- applies monitor rules at the end of the config run.
local function rehome_soon()
    hl.timer(rehome_workspaces, { timeout = 500, type = "oneshot" })
end
hl.on("monitor.added", rehome_soon)
hl.on("config.reloaded", rehome_soon)

-- Unplugging the last external screen while the lid is shut (on AC, where
-- logind ignores the lid) would leave nothing lit: reload, and with no
-- external screen left the config lights the panel whatever the lid says.
hl.on("monitor.removed", function()
    if external_count() == 0 then hl.dispatch(hl.dsp.reload_config()) end
end)

--------------------------------
---- WINDOWS AND WORKSPACES ----
--------------------------------

-- The [[on-window-detected]] equivalents.
--
-- AeroSpace matches on macOS bundle IDs; Hyprland matches on Wayland app_id or
-- XWayland class. The values below came from each app's StartupWMClass.
-- Verify a window's real class with: hyprctl clients
--
-- Matching uses Google RE2, which has no lookahead or backreferences. To
-- negate, prefix the pattern with "negative:" - do NOT use (?!...), it will
-- silently fail to match.
--
-- Workspace assignment is a static effect: it is evaluated once at window
-- open, against the *initial* class and title.

-- Workspace 1 - terminal
hl.window_rule({
    name  = "ghostty-ws1",
    match = { class = [[^com\.mitchellh\.ghostty$]] },
    workspace = 1,
})

-- Workspace 2 - all browsers, grouped (the accordion-layout equivalent).
-- Translucent by default at the SUPER+Backspace level (translucent_opacity);
-- keep this class list in sync with translucent_by_default up there.
hl.window_rule({
    name  = "browsers-ws2",
    match = { class = [[^(firefox-esr|brave-browser|google-chrome)$]] },
    workspace = 2,
    opacity   = translucent_opacity,
})

-- Workspace 5 - Obsidian (the CWES vault). Translucent by default, like the
-- browsers; keep in sync with translucent_by_default.
hl.window_rule({
    name  = "obsidian-ws5",
    match = { class = [[^(obsidian|md\.obsidian\.Obsidian)$]] },
    workspace = 5,
    opacity   = translucent_opacity,
})

-- Workspace 6 - dev/security tooling. On macOS this was Postman, pgAdmin and
-- Docker Desktop; none are installed here, so it holds the HTB GUI tools.
-- Burp is Java/Swing under XWayland.
hl.window_rule({
    name  = "burp-ws6",
    match = { class = [[^burp-StartBurp$]] },
    workspace = 6,
})

hl.window_rule({
    name  = "wireshark-ws6",
    -- Wireshark 4.6 reports its reverse-DNS app id; older builds "wireshark".
    match = { class = [[^(wireshark|org\.wireshark\.Wireshark)$]] },
    workspace = 6,
})

-- Workspace 8 - chat. On macOS this slot is Slack; Slack has no Linux install
-- here yet, so Discord takes it. If Slack arrives later it belongs here too.
-- Translucent by default, like the browsers; keep in sync with
-- translucent_by_default.
hl.window_rule({
    name  = "discord-ws8",
    match = { class = [[^(discord|Discord)$]] },
    workspace = 8,
    opacity   = translucent_opacity,
})

-- Workspace 10 - keyboard config (AeroSpace's workspace 0)
hl.window_rule({
    name  = "keymapp-ws10",
    match = { class = [[^keymapp$]] },
    workspace = 10,
})

-- Floating - the 'com.apple.finder' -> layout floating equivalent
hl.window_rule({
    name  = "float-utilities",
    -- Real classes, confirmed with `hyprctl clients`. Note pavucontrol reports
    -- org.pulseaudio.pavucontrol, not "pavucontrol" - the short name silently
    -- matched nothing.
    match = { class = [[^(org\.gnome\.Nautilus|thunar|org\.pulseaudio\.pavucontrol|nm-connection-editor)$]] },
    float = true,
})

-- The network picker opened from waybar's network module: nmtui in its own
-- Ghostty window. The custom class keeps it off ghostty-ws1 and floats it.
hl.window_rule({
    name  = "float-nmtui",
    match = { class = [[^local\.nmtui$]] },
    float = true,
    size  = { 720, 520 },
    center = true,
})

hl.window_rule({
    name  = "float-file-dialogs",
    match = { title = [[^(Open File|Save File|Select a File)$]] },
    float = true,
})

-- No app rule for workspace 7 - it is the blackhole, kept empty by design
-- (same as the AeroSpace config's comment on workspace 7).

---------------------
---- LAYER RULES ----
---------------------

-- swaync draws at 0.8 alpha like ghostty and waybar; this puts the same blur
-- behind it. Both namespaces are full-screen and mostly transparent (swaync's
-- layer-shell-cover-screen, and the invisible click-catcher behind the
-- panel), so ignore_alpha keeps the blur to the cards themselves instead of
-- frosting the whole screen. 0.5 sits under the cards' 0.8 and over their
-- shadows.
-- waybar is also 0.8 alpha (style.css), but got no blur, so it read as a
-- tinted strip rather than frosted glass like ghostty below it. The bar is
-- one full-width surface; ignore_alpha keeps fully transparent gaps sharp.
hl.layer_rule({
    name         = "waybar-blur",
    match        = { namespace = "^waybar$" },
    blur         = true,
    ignore_alpha = 0.2,
})

-- SwayOSD's volume/brightness pill, 0.85 alpha like the rest.
hl.layer_rule({
    name         = "swayosd-blur",
    match        = { namespace = "^swayosd$" },
    blur         = true,
    ignore_alpha = 0.2,
})

hl.layer_rule({
    name         = "swaync-blur",
    match        = { namespace = "^swaync-(control-center|notification-window)$" },
    blur         = true,
    ignore_alpha = 0.5,
})
