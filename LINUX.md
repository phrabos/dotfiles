# Linux (Debian / Kali)

The `Brewfile` does not apply here. Homebrew is not used on Linux; every tool
comes from apt, a vendor apt repo, npm, uv, or a release binary in
`~/.local/bin`. This file is the package-by-package translation.

Verified on Kali rolling 2026.2 (XFCE, x86_64, glibc 2.42, GTK 4.22).

## Two Debian gotchas

**Binary renames.** Debian ships `bat` as `batcat` and `fd` as `fdfind`, to
avoid clashes with unrelated packages. The configs in this repo call them by
their upstream names, so `~/.local/bin` carries shims and `.zprofile` puts that
directory ahead of `/usr/bin`:

```bash
ln -sf "$(command -v batcat)" ~/.local/bin/bat
ln -sf "$(command -v fdfind)" ~/.local/bin/fd
```

Aliasing in `.zshrc` alone is not enough — nvim, fzf and lazygit shell out to
`bat` and `fd` directly and never see a shell alias.

**Kali is not Debian stable.** It tracks Debian testing/sid, so packages built
for `trixie` may be older than what is installed. Where a project publishes
per-codename builds, take the `forky`/`sid` one.

## From apt

```bash
sudo apt install -y \
  aerc bat btop direnv eza fd-find ffmpeg ffuf fzf jq lazygit maven neovim \
  nmap openvpn poppler-utils posting ripgrep stow tree w3m xh yt-dlp azure-cli
```

`postgresql` (18) and `wireshark` ship with Kali already. The Brewfile pins
`postgresql@17`; Kali offers 18. Add the PGDG repo if 17 specifically matters.

## From a vendor apt repo

**GitHub CLI**

```bash
sudo install -d -m 0755 /etc/apt/keyrings
sudo curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
  -o /etc/apt/keyrings/githubcli-archive-keyring.gpg
sudo chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
  | sudo tee /etc/apt/sources.list.d/github-cli.list
sudo apt update && sudo apt install gh
```

**cloudflared** — Cloudflare publishes a single `any` suite, so Kali's codename
is not a problem.

```bash
sudo curl -fsSL https://pkg.cloudflare.com/cloudflare-main.gpg \
  -o /usr/share/keyrings/cloudflare-main.gpg
echo "deb [signed-by=/usr/share/keyrings/cloudflare-main.gpg] https://pkg.cloudflare.com/cloudflared any main" \
  | sudo tee /etc/apt/sources.list.d/cloudflared.list
sudo apt update && sudo apt install cloudflared
```

## Ghostty

Not in apt, and Debian has no `ghostty` package at all. The official docs point
at [ghostty-ubuntu](https://github.com/mkasberg/ghostty-ubuntu), but **its
install script does not work on Kali 2026** — its Kali version map only covers
`2025`, and it would pick the `trixie` build, which is older than Kali's
libraries. Take the `forky` `.deb` directly:

```bash
curl -fsSLO https://github.com/mkasberg/ghostty-ubuntu/releases/download/1.3.1-0-ppa2/ghostty_1.3.1-0.ppa2_amd64_forky.deb
sudo apt install -y ./ghostty_1.3.1-0.ppa2_amd64_forky.deb
```

The `.deb` is preferred over the AppImage because it installs system terminfo
(`xterm-ghostty`), the launcher `.desktop`, zsh shell-integration and
completions — all of which the AppImage would require hand-rolling, with a
`.desktop` pointing at a versioned path that breaks on update.

### Making it the default terminal

Three separate mechanisms, all needed. XFCE ignores Debian's alternatives
system for its own launchers, which is the usual reason Ghostty "won't stick".

```bash
# 1. Debian alternatives
sudo update-alternatives --install /usr/bin/x-terminal-emulator \
  x-terminal-emulator /usr/bin/ghostty 60
sudo update-alternatives --set x-terminal-emulator /usr/bin/ghostty

# 2. freedesktop terminal-exec spec
echo com.mitchellh.ghostty.desktop > ~/.config/xdg-terminals.list

# 3. XFCE / exo — needs a helper file; there is no stock Ghostty helper
printf '[Configuration]\nTerminalEmulator=ghostty\n' > ~/.config/xfce4/helpers.rc
```

The helper itself lives at `~/.local/share/xfce4/helpers/ghostty.desktop`:

```ini
[Desktop Entry]
Version=1.0
Type=X-XFCE-Helper
Icon=com.mitchellh.ghostty
Name=Ghostty
StartupNotify=true
X-XFCE-Binaries=ghostty;
X-XFCE-Category=TerminalEmulator
X-XFCE-Commands=%B;
X-XFCE-CommandsWithParameter=%B -e %s;
```

Verify with `exo-open --launch TerminalEmulator "sleep 5"` — it should spawn
`ghostty -e`.

## Fonts

The `font-iosevka-*-nerd-font` casks have no Linux equivalent. Without them
starship, eza icons, lazygit and LazyVim render tofu.

```bash
mkdir -p ~/.local/share/fonts/NerdFonts
for f in IosevkaTerm Iosevka; do
  curl -fsSLO "https://github.com/ryanoasis/nerd-fonts/releases/download/v3.5.0/${f}.tar.xz"
  mkdir -p "unpack_$f" && tar -xJf "${f}.tar.xz" -C "unpack_$f"
  find "unpack_$f" -name '*.ttf' -exec cp {} ~/.local/share/fonts/NerdFonts/ \;
done
fc-cache -f ~/.local/share/fonts
```

## Release binaries → `~/.local/bin`

Verify checksums where published. Note zellij's `.sha256sum` names the binary by
its *build path*, so `sha256sum -c` against the tarball silently checks nothing —
compare the extracted binary's hash by hand.

| Tool | Source |
|---|---|
| `starship` | `curl -fsSL https://starship.rs/install.sh \| sh -s -- -b ~/.local/bin -y` |
| `mise` | `curl -fsSL https://mise.run \| sh` |
| `uv` | `curl -fsSL https://astral.sh/uv/install.sh \| env UV_INSTALL_DIR=~/.local/bin INSTALLER_NO_MODIFY_PATH=1 sh` |
| `atuin` | GitHub release `atuin-x86_64-unknown-linux-gnu.tar.gz` |
| `carapace` | GitHub release `carapace-bin_*_linux_amd64.tar.gz` |
| `zellij` | GitHub release `zellij-x86_64-unknown-linux-musl.tar.gz` |
| `worktrunk` | GitHub release `worktrunk-x86_64-unknown-linux-musl.tar.xz` |
| `pulumi` | `curl -fsSL https://get.pulumi.com \| sh -s -- --install-root ~/.local --no-edit-path` |

**Do not use the vendor `curl | sh` installers that offer to edit your shell
config.** `~/.zshrc` is a symlink into this repo, so an installer appending an
init line writes into version control. Pass the flag that suppresses it
(`--no-edit-path`, `INSTALLER_NO_MODIFY_PATH=1`, `-b`) or install the binary by
hand.

## npm (via mise-managed node)

```bash
npm install -g @fission-ai/openspec firebase-tools @dotenvx/dotenvx
mise reshim
```

`corepack` comes from mise (`[settings.node] corepack = true`), not npm.

`npm:@microsoft/inshellisense` is declared in `mise/.config/mise/config.toml`,
but mise's `aube` backend aborts with "user aborted" in a non-interactive shell
regardless of `MISE_YES=1`. Install it through npm instead:

```bash
mise exec node@24 -- npm install -g @microsoft/inshellisense && mise reshim
```

It backs `CARAPACE_BRIDGES='inshellisense,zsh'` in `.zshrc`.

## uv tools

```bash
uv tool install ruff
uv tool install pytest
uv tool install pre-commit
```

## GUI apps (casks)

**Brave** — official apt repo, deb822 format. Publishes a single `stable`
suite, so Kali's codename is irrelevant.

```bash
sudo curl -fsSLo /usr/share/keyrings/brave-browser-archive-keyring.gpg \
  https://brave-browser-apt-release.s3.brave.com/brave-browser-archive-keyring.gpg
sudo curl -fsSLo /etc/apt/sources.list.d/brave-browser-release.sources \
  https://brave-browser-apt-release.s3.brave.com/brave-browser.sources
sudo apt update && sudo apt install brave-browser
```

**Google Chrome** — the `.deb` installs its own apt source, so it updates
through apt afterwards.

```bash
curl -fsSLO https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
sudo apt install -y ./google-chrome-stable_current_amd64.deb
```

Chrome's `Depends` list names pre-t64 packages (`libasound2`, `libgtk-3-0`,
`libglib2.0-0`…). They look missing to `dpkg-query` on a modern Debian, but the
`*t64` packages satisfy them via `Provides` — check with
`apt-get install --no-act`, not by hand.

**Discord** — direct `.deb`. The package is only ~2 MB and that is correct: it
ships an `updater_bootstrap` that fetches the app on first run.

```bash
curl -fsSL -o discord.deb "https://discord.com/api/download?platform=linux&format=deb"
sudo apt install -y ./discord.deb
```

**Obsidian** — `.deb` from GitHub releases (`obsidianmd/obsidian-releases`).

**Tailscale** — publishes a real `sid` suite, an exact match for Kali. No
codename guessing.

```bash
sudo curl -fsSL https://pkgs.tailscale.com/stable/debian/sid.noarmor.gpg \
  -o /usr/share/keyrings/tailscale-archive-keyring.gpg
sudo curl -fsSL https://pkgs.tailscale.com/stable/debian/sid.tailscale-keyring.list \
  -o /etc/apt/sources.list.d/tailscale.list
sudo apt update && sudo apt install tailscale
```

**Docker Engine** — Docker publishes only `bookworm` and `trixie` for Debian;
there is no `sid` or `forky`. Use `trixie`. Docker Desktop is not used here —
Engine plus the compose and buildx plugins is what sbx needs.

```bash
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc
echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian trixie stable" \
  | sudo tee /etc/apt/sources.list.d/docker.list
sudo apt update
sudo apt install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
sudo usermod -aG docker "$USER"   # takes effect on next login
```

**Docker Sandboxes (sbx)** — needs KVM hardware virtualisation and `e2fsprogs`.
`docker-sbx` is in Docker's *Ubuntu* repo but **not** the Debian one, and the
`.deb` assets are Ubuntu-built, so take the distro-agnostic tarball. Install to
`/usr/local` rather than the default `~/.docker/sbx`: AppArmor is active on
Kali, and the bundled `install.sh` needs root to register its profile.

```bash
curl -fsSLO https://github.com/docker/sbx-releases/releases/download/v0.39.0/DockerSandboxes-linux-amd64.tar.gz
tar -xzf DockerSandboxes-linux-amd64.tar.gz
sudo env PREFIX=/usr/local bash docker-sbx/install.sh
```

**ProtonVPN** — Proton's repo is broken on Kali. Its `python3-proton-core`
0.7.4 depends on `python3-importlib-metadata`, which Debian removed because
`importlib.metadata` has been stdlib since Python 3.8 (Kali ships 3.13). The
entire Proton chain is uninstallable from Proton's repo alone.

Kali packages its own `python3-proton-core` 0.7.0-1 without that dependency.
Pin to it, then hold — otherwise apt "upgrades" into Proton's broken 0.7.4.

```bash
curl -fsSLO https://repo.protonvpn.com/debian/dists/stable/main/binary-all/protonvpn-stable-release_1.0.8_all.deb
sudo apt install -y ./protonvpn-stable-release_1.0.8_all.deb
sudo apt update
sudo apt install -y proton-vpn-gnome-desktop python3-proton-core=0.7.0-1
sudo apt-mark hold python3-proton-core
```

Verify the hold with `dpkg --get-selections | grep proton-core` — `apt-mark
showhold` prints nothing on this apt version even when the hold is set.

Still to do: Slack, gcloud, Proton Mail Bridge, pgAdmin4, GnuCash, Zen,
keymapp. Firefox and Wireshark already ship with Kali.

## Hyprland desktop

The compositor and its tooling come from apt:

```bash
sudo apt install -y hyprland hyprpaper hyprlock hypridle hyprshutdown \
  hyprland-guiutils hyprlauncher xdg-desktop-portal-hyprland xwayland \
  waybar sway-notification-center cliphist grim slurp wl-clipboard swappy playerctl \
  brightnessctl nwg-displays papirus-icon-theme sassc
```

Note `hyprland-qtutils` is a transitional package — install `hyprland-guiutils`.
`mako` has no candidate in Kali, so the notification daemon is **swaync**
(SwayNotificationCenter, package `sway-notification-center`, 0.12.6 at the time
of writing). It replaced dunst: same popups, plus a control-center panel with
history, Do Not Disturb, media controls, volume and brightness sliders and
Wi-Fi / Bluetooth / mic toggles.

- `SUPER+N` opens the panel (so does the waybar bell), `SUPER+SHIFT+N`
  toggles Do Not Disturb, `SUPER+CTRL+N` dismisses the newest popup.
  Right-clicking the bell also toggles Do Not Disturb.
- `hyprland.lua` starts `swaync` directly. Do not rely on its systemd unit,
  which is `PartOf=graphical-session.target`, a target this session never
  starts.
- Config is `swaync/.config/swaync/`. `config.json` is validated by
  `/etc/xdg/swaync/configSchema.json`: point a JSON language server at it via
  the `$schema` key. `style.css` is layered over the packaged
  `/etc/xdg/swaync/style.css` and mostly just overrides its CSS variables.
- Apply edits without a restart: `swaync-client -R` (config) and
  `swaync-client -rs` (CSS). Debug with `GTK_DEBUG=interactive swaync --replace`.
- The quick-settings buttons call `~/.local/bin/swaync-toggle`.

Once swaync is running, remove dunst so its D-Bus service file stops competing
for `org.freedesktop.Notifications`:

```bash
sudo apt purge -y dunst
```

### Sleep, hibernate and the power menu

Same model as Omarchy v3: the lid **suspends**, and **Hibernate is manual**.
Pick it from the power menu before the laptop goes in a bag.

Why not `suspend-then-hibernate`: this laptop (T14s Gen 2i) only has s2idle
suspend, and the RTC alarm cannot wake it from s2idle to do the hibernate half
without the `rtc_cmos.use_acpi_alarm=1` kernel parameter. It sat in s2idle
until the battery died and cold-booted, losing the session: 09-16, 09-17 and
09-19 in the journal, about a day from 100% each time. Omarchy dropped
suspend-then-hibernate for the same reason ("stuck in a suspend-wake-up loop"
on too many laptops).

| Situation | What happens | Configured in |
|---|---|---|
| Idle 2.5 / 5 / 5.5 min | dim, lock, screen off | `hypr/hypridle.conf` |
| Idle 60 min on battery | hibernate (safety net; nothing on AC) | `hypr/hypridle.conf` |
| Any sleep | locks first, sleep waits for the lock | `hypr/hypridle.conf` |
| Lid closed on battery | suspend (drains in ~1 day) | `system/…/logind.conf.d/10-power.conf` |
| Lid closed on AC / docked | nothing | same |
| Power button (running) | power menu | same + `hyprland.lua` |
| Power button (off / hibernated) | powers on (firmware) | — |
| Battery 20% / 10% | waybar warnings | `waybar/config.jsonc` |
| Battery 5% while awake | hibernate | `system/…/UPower.conf.d/50-hibernate.conf` |

The power menu (`~/.local/bin/power-menu`, a Vicinae list) opens from the power
button, `CTRL+ALT+Delete`, the waybar ⏻ chip and the swaync power button.
Log out / reboot / shut down run `hyprshutdown` through
`hyprctl dispatch "hl.dsp.exec_cmd(...)"`, so it is Hyprland's child whichever
of these opened the menu: started as a child of waybar or swaync it closed
the apps and then sat on a blank screen
([hyprshutdown#15](https://github.com/hyprwm/hyprshutdown/issues/15)). The
menu logs the choice and Hyprland's reply: `journalctl -t power-menu`.

Hibernate resumes from the existing 10.3 GB swap partition
(`RESUME=UUID=…` in `/etc/initramfs-tools/conf.d/resume`, from the
installer). That is enough even with 15 GB of RAM: the kernel shrinks the
image to about `/sys/power/image_size` (2/5 of RAM) and LZO-compresses it as
it writes. No swapfile: resuming from a swap *file* on initramfs-tools needs
`resume_offset=` on the kernel command line.

Install the system files (`system/` is never stowed: these are root-owned):

```bash
sudo install -Dm644 system/etc/systemd/logind.conf.d/10-power.conf \
  /etc/systemd/logind.conf.d/10-power.conf
sudo rm -f /etc/systemd/logind.conf.d/10-lid-hibernate.conf
sudo install -Dm644 system/etc/UPower/UPower.conf.d/50-hibernate.conf \
  /etc/UPower/UPower.conf.d/50-hibernate.conf

sudo systemctl reload systemd-logind   # re-reads config; never *restart* it, that ends the session
sudo systemctl restart upower
```

Then test hibernate once with your usual apps open: `systemctl hibernate`,
press the power button, and check the session comes back.

### Theming beyond the config files

Everything is Catppuccin Mocha with a mauve accent (mauve -> pink on focused
borders). Most of it is in stowed packages; these pieces need packages or
root:

```bash
# Volume / brightness / media-key popup, and Hyprland's polkit agent
# (replaces the MATE agent; a Qt 6 app, so the qt package themes it).
sudo apt install -y swayosd hyprpolkitagent

# Qt 6 apps (Wireshark): the `qt` stow package holds qt6ct.conf and the
# official catppuccin/qt5ct colour scheme. hyprland.lua already sets
# QT_QPA_PLATFORMTHEME=qt6ct. qt6ct rewrites its conf on Apply - the
# dotfiles copy is canonical.
stow qt swayosd

# Mauve folder icons: catppuccin/papirus-folders + Papirus's own script.
git clone --depth 1 https://github.com/catppuccin/papirus-folders.git
curl -LO https://raw.githubusercontent.com/PapirusDevelopmentTeam/papirus-folders/master/papirus-folders
chmod +x papirus-folders
sudo cp -r papirus-folders/src/* /usr/share/icons/Papirus/
sudo ./papirus-folders -C cat-mocha-mauve --theme Papirus-Dark
```

A `papirus-icon-theme` upgrade can reset the folders to blue; re-run the last
line. SwayOSD's brightness control writes `/sys/class/backlight` directly,
which works because this user is in the `video` group.

### Boot and login screens

Power-on to login is GRUB -> Plymouth -> GDM, all Catppuccin Mocha. The
Lenovo logo is the firmware's, and GRUB's "Loading Linux ..." line is
hard-coded by Debian (`quiet_boot="0"` in `/etc/grub.d/10_linux`).

**Early KMS first.** Kali's initramfs includes the i915 driver but does not
load it, so it came up ~0.3 s after the display manager. That is why Kali's
stock lightdm showed no login screen here (only the tty1 text login; a
greeter appeared after `sudo chvt 7`). Loading i915 in the initramfs fixes
it, and it needs `thinkpad_acpi` first: on this T14s the kernel registers a
privacy-screen provider, and i915 defers its probe until thinkpad_acpi is
loaded (kernel >= 5.17). dracut and mkinitcpio's `kms` hook add
privacy-screen drivers themselves; initramfs-tools does not. i915 is now up
at ~3 s, the display manager starts at ~7 s. Kernel updates rebuild their
initramfs from the same file (`/etc/kernel/postinst.d/initramfs-tools`).

```bash
sudo install -m644 system/etc/initramfs-tools/modules /etc/initramfs-tools/modules
sudo update-initramfs -u      # newest kernel only; older ones stay as a fallback
# After a kernel update, i915 should initialise before gdm starts:
dmesg | grep 'Initialized i915'; journalctl -b -o short-monotonic | grep -m1 'Starting gdm'
```

**GRUB** - [catppuccin/grub](https://github.com/catppuccin/grub) Mocha. The
drop-in is named `zz-` so it loads after Kali's package-owned
`kali-themes.cfg`; its empty `GRUB_BACKGROUND` stops `05_debian_theme` putting
Kali's image behind the `e` editor and `c` console.

```bash
git clone https://github.com/catppuccin/grub.git && git -C grub checkout 0a37ab1
sudo cp -r --no-preserve=mode,ownership grub/src/catppuccin-mocha-grub-theme /boot/grub/themes/catppuccin-mocha
sudo install -m644 system/etc/default/grub.d/zz-catppuccin.cfg /etc/default/grub.d/
sudo update-grub              # should print "Found theme: ..."
```

**Plymouth** - [catppuccin/plymouth](https://github.com/catppuccin/plymouth)
Mocha, which shows at boot, shutdown and hibernate resume. Its `watermark.png`
is a transparent 1x1 image of ours: Debian's initramfs hook copies the Debian
swirl in as the watermark of any `two-step` theme that lacks one. Don't use
`plymouth-set-default-theme -R` - on Debian that rebuilds every kernel's
initramfs (`update-initramfs -u -k all`).

```bash
git clone https://github.com/catppuccin/plymouth.git && git -C plymouth checkout 198eba2
sudo cp -r --no-preserve=mode,ownership plymouth/themes/catppuccin-mocha /usr/share/plymouth/themes/
sudo install -m644 system/usr/share/plymouth/themes/catppuccin-mocha/watermark.png \
  /usr/share/plymouth/themes/catppuccin-mocha/
sudo plymouth-set-default-theme catppuccin-mocha
sudo update-initramfs -u
```

**GDM** stays the display manager. lightdm (even with the race fixed) starts
Wayland sessions before logind has made them active, so Hyprland came up
without the built-in keyboard, TrackPoint and touchpad
([lightdm#63](https://github.com/canonical/lightdm/issues/63), open since
2019; [Hyprland#8278](https://github.com/hyprwm/Hyprland/issues/8278)).
greetd + tuigreet looked sound and SDDM + catppuccin/sddm was risky; neither
is installed.

GDM can only be themed partly without replacing gnome-shell's package-owned
theme gresource (not done: a bad one means no login screen, and every
gnome-shell update overwrites it). What is set:

- `system/usr/share/gdm/dconf/95-catppuccin`: pink accent (GNOME's fixed
  accent set), dark, Iosevka, Catppuccin cursor, 24h clock, no Kali logo.
  `gdm.service` compiles `/usr/share/gdm/dconf/*` in name order on every
  start, so 95 beats Debian's 90 and Kali's 92. **A malformed file stops gdm
  starting** - test-compile it first (below). Not `/etc/dconf/profile/gdm`,
  the upstream / Arch way: on Debian it bypasses the Debian and Kali layers.
- The background: Kali's gnome-shell patch hard-codes
  `/usr/share/desktop-base/kali-theme/login/background-blurred`. A dpkg
  diversion moves Kali's symlink aside (updates then write there) and ours
  points at a blurred, Mocha-tinted copy of the current wallpaper.
- The avatar is the Catppuccin logo, set per user through AccountsService
  (no sudo), so any display manager shows it.
- Font and cursor copied system-wide: the greeter runs as its own user.

```bash
sudo install -Dm644 -t /usr/local/share/fonts/iosevka-nerd \
  ~/.local/share/fonts/NerdFonts/IosevkaNerdFont-{Regular,Bold}.ttf && sudo fc-cache
sudo cp -r ~/.local/share/icons/catppuccin-mocha-mauve-cursors /usr/share/icons/

# Test-compile against the other layers as a normal user, then install.
mkdir -p /tmp/gdmtest/d && cp -L /usr/share/gdm/dconf/[0-9]* /tmp/gdmtest/d/ &&
  cp system/usr/share/gdm/dconf/95-catppuccin /tmp/gdmtest/d/ &&
  dconf compile /tmp/gdmtest/out /tmp/gdmtest/d && echo OK
sudo install -m644 system/usr/share/gdm/dconf/95-catppuccin /usr/share/gdm/dconf/

# Login background (re-run the magick line after changing wallpaper).
magick ~/.local/state/wallpaper/current -resize 1920x1080^ -gravity center \
  -extent 1920x1080 -blur 0x28 -fill '#1e1e2e' -colorize 25% /tmp/login-blurred.jpg
sudo install -Dm644 /tmp/login-blurred.jpg /usr/local/share/backgrounds/login-blurred.jpg
sudo dpkg-divert --local --rename \
  --divert /usr/share/desktop-base/kali-theme/login/background-blurred.kali \
  --add /usr/share/desktop-base/kali-theme/login/background-blurred
sudo ln -s /usr/local/share/backgrounds/login-blurred.jpg \
  /usr/share/desktop-base/kali-theme/login/background-blurred

# Avatar: official Catppuccin logo (MIT).
curl -Lo /tmp/cat.png https://raw.githubusercontent.com/catppuccin/catppuccin/main/assets/logos/exports/1544x1544_circle.png
magick /tmp/cat.png -resize 256x256 /tmp/cat.png
busctl call org.freedesktop.Accounts /org/freedesktop/Accounts/User$(id -u) \
  org.freedesktop.Accounts.User SetIconFile s /tmp/cat.png
```

Undo: remove `95-catppuccin`; for the background, remove our symlink and
`sudo dpkg-divert --rename --remove <path>`.

### Window switcher — hyprshell

The Cmd+Tab overlay on `Super+Tab` is [hyprshell](https://github.com/H3rmt/hyprshell)
(the renamed successor of hyprswitch). It is not packaged in Kali; take the
release tarball. It needs Hyprland 0.55+ with the Lua config, GTK 4.18+ and
libadwaita 1.8+, all of which Kali already has — only the layer-shell library is
missing:

```bash
sudo apt install -y libgtk4-layer-shell0
gh release download v4.10.8 -R H3rmt/hyprshell -p 'hyprshell-4.10.8-x86_64.tar.zst'
tar --zstd -xf hyprshell-4.10.8-x86_64.tar.zst hyprshell
install -m755 hyprshell ~/.local/bin/hyprshell
stow hyprshell
```

`hyprland.lua` autostarts `hyprshell run`, which registers its own binds over
IPC — there are no switcher binds in the Hyprland config. The shipped
`hyprshell.service` hardcodes `/usr/bin/hyprshell`, so it is not used.

### Search launcher — Vicinae

`Super+Space` (Cmd+Space) is [Vicinae](https://github.com/vicinaehq/vicinae),
a Spotlight/Raycast-style launcher: apps, files, calculator, clipboard history.
Not packaged in Kali. The release tarball needs glibc 2.44 and Qt 6.11 (Kali
has 2.43 / 6.10), so use the AppImage, which bundles Qt and only needs glibc
2.35. It is extracted rather than run directly, so each `vicinae toggle` does
not remount a 100 MB image:

```bash
gh release download v0.29.0 -R vicinaehq/vicinae -p 'Vicinae-x86_64.AppImage'
chmod +x Vicinae-x86_64.AppImage && ./Vicinae-x86_64.AppImage --appimage-extract
mkdir -p ~/.local/opt && mv squashfs-root ~/.local/opt/vicinae
# A wrapper, not a symlink: AppRun locates itself from $0.
printf '#!/bin/sh\nexec "$HOME/.local/opt/vicinae/AppRun" "$@"\n' > ~/.local/bin/vicinae
chmod +x ~/.local/bin/vicinae
# Desktop entry + icon, so the desktop portal recognises the app ID.
cp ~/.local/opt/vicinae/usr/share/applications/vicinae*.desktop ~/.local/share/applications/
cp ~/.local/opt/vicinae/usr/share/icons/hicolor/512x512/apps/vicinae.png ~/.local/share/icons/hicolor/512x512/apps/
# Create the data dir first, or stow folds all of ~/.local/share/vicinae into
# the repo and Vicinae writes its databases there.
mkdir -p ~/.local/share/vicinae && stow vicinae
```

`hyprland.lua` autostarts `vicinae server`; the bind only runs `vicinae toggle`.
The `vicinae` package carries `settings.json` (theme, telemetry off, files in
root search) and a `catppuccin-mocha-mauve` theme - the
bundled Catppuccin Mocha with the mauve accent instead of blue. Vicinae writes
settings changes made in its GUI back to `settings.json`, i.e. into the repo.

`close_on_focus_loss` is off (Vicinae's own default). With Hyprland's
focus-follows-mouse and the layer shell's `on_demand` keyboard mode, crossing
any window on the way to a Vicinae menu took focus and closed it; the power
menu's `vicinae dmenu` client was then never answered and hung. Esc or
`Super+Space` closes Vicinae. `exclusive` keyboard mode would also avoid it,
but Vicinae warns it breaks mouse use in popups on Hyprland.
On first start it also drops browser native-messaging manifests into the
Chrome/Chromium/Brave config dirs for its optional browser extension.

### Theming — not packaged, and the official theme is dead

`catppuccin/gtk` was archived in June 2024. The maintained successor is
[Fausto-Korpsvart/Catppuccin-GTK-Theme](https://github.com/Fausto-Korpsvart/Catppuccin-GTK-Theme),
which unlike the original handles GTK4/libadwaita.

```bash
git clone --depth 1 https://github.com/Fausto-Korpsvart/Catppuccin-GTK-Theme.git
cd Catppuccin-GTK-Theme/themes
./install.sh -d ~/.local/share/themes -a mauve -m dark -l
```

Mocha is the default flavour; frappé and macchiato are opt-in `--tweaks`. The
installer needs `sassc` and will try to `sudo apt install` it itself, which
fails without a TTY — install it first. It also ends on an interactive GNOME
Shell prompt that errors out under a non-interactive shell; the GTK theme is
already fully installed by then, so that error is safe to ignore. The one thing
it skips on that error is the `-l` libadwaita link, done by hand:

```bash
T=~/.local/share/themes/Catppuccin-Mauve-Dark/gtk-4.0
for f in gtk.css gtk-dark.css assets; do ln -sfn "$T/$f" ~/.config/gtk-4.0/$f; done
```

**Stow trap:** if `~/.config/gtk-4.0` is a folded *directory* symlink into this
repo, that loop writes a 600 MB theme into version control. The `gtk` package
must be stowed with `--no-folding` so only `settings.ini` is linked.

Cursors come from [catppuccin/cursors](https://github.com/catppuccin/cursors)
releases — the zip carries a native `hyprcursors/` directory as well as
XCursor, so both `HYPRCURSOR_THEME` and `XCURSOR_THEME` are set:

```bash
curl -fsSLO https://github.com/catppuccin/cursors/releases/download/v2.0.0/catppuccin-mocha-mauve-cursors.zip
unzip -q catppuccin-mocha-mauve-cursors.zip -d ~/.local/share/icons/
```

Icons are stock `Papirus-Dark`. Catppuccin folder recolouring needs
[catppuccin/papirus-folders](https://github.com/catppuccin/papirus-folders)
copied into `/usr/share/icons/Papirus/` — it cannot be done per-user, because
Papirus-Dark symlinks its 32/48/64/128px directories into `../Papirus/` and so
is not standalone.

Themes live in `~/.local/share/{themes,icons}` and are deliberately **not** in
this repo — too large, and machine-local.

### nwg-displays needs a shim under the Lua config

nwg-displays writes hyprlang `monitor=` lines to `~/.config/hypr/monitors.conf`
and its docs say to add `source = ...` to your config. There is no `source` in
the Lua config, so that file would be written and silently ignored. `hypr`'s
`hyprland.lua` reads it and replays each line through `hl.monitor()` instead.

## Dropped — macOS only

| Brewfile entry | Why |
|---|---|
| `duti` | sets default apps on macOS; replaced by `update-alternatives` + `xdg-terminals.list` + the XFCE helper above |
| `aerospace` | macOS tiling WM; the Linux counterpart is the `hypr` package (Hyprland), which mirrors the same keybindings |
| `shortcat`, `krisp`, `freedom` | no Linux build |
| `claude` (cask) | no official Linux desktop app |
| `font-iosevka-*` casks | replaced by the Nerd Fonts release tarballs above |

Everything else has a Linux equivalent — see the GUI apps section above.

## Still manual

Interactive auth, unchanged from the macOS list:

```bash
gh auth login
gcloud auth login
firebase login
atuin login && atuin sync
openspec config profile
```
