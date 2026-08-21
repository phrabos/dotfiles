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

## Dropped — macOS only

| Brewfile entry | Why |
|---|---|
| `duti` | sets default apps on macOS; replaced by `update-alternatives` + `xdg-terminals.list` + the XFCE helper above |
| `aerospace` | macOS tiling WM |
| `shortcat`, `krisp`, `freedom` | no Linux build |
| `claude` (cask) | no official Linux desktop app |
| `font-iosevka-*` casks | replaced by the Nerd Fonts release tarballs above |

Most other casks have Linux equivalents (Brave, Chrome, Firefox, Discord,
Slack, Obsidian, Docker, gcloud, ProtonVPN, Proton Mail Bridge, Tailscale,
pgAdmin4, GnuCash, Wireshark) — each its own apt repo or `.deb`. Not yet done.

## Still manual

Interactive auth, unchanged from the macOS list:

```bash
gh auth login
gcloud auth login
firebase login
atuin login && atuin sync
openspec config profile
```
