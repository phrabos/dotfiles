# dotfiles

Managed with [GNU Stow](https://www.gnu.org/software/stow/). Each top-level
directory is a "package" whose contents mirror the path relative to `$HOME`.

```
dotfiles/zsh/.zshrc              ->  ~/.zshrc
dotfiles/nvim/.config/nvim/      ->  ~/.config/nvim/
```

The files in `$HOME` are **symlinks into this repo**, so editing `~/.zshrc`
edits `zsh/.zshrc` here. One file, two paths — no sync step, no drift.

## Platform split

`zsh` is split across three packages, because the shell config genuinely
diverges and neither side should carry the other's dead branches:

| Package | Contents | Stow on |
|---|---|---|
| `zsh` | `.zshenv` `.zsh_plugins.txt` `.config/zsh/` | both |
| `zsh-macos` | `.zshrc` `.zprofile` (Homebrew, `/opt/homebrew` paths) | macOS |
| `zsh-linux` | `.zshrc` `.zprofile` (apt, `~/.antidote`, no Homebrew) | Linux |

Each `.zshrc` is standalone — no `$OSTYPE` checks, no guarded no-ops.

**This means `stow */` no longer works**: it would try to link both `.zshrc`
files onto the same target. Use the platform command below.

## Bootstrap a new Mac

```bash
xcode-select --install
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

git clone git@github.com:phrabos/dotfiles.git ~/dotfiles
cd ~/dotfiles

brew bundle --file=./Brewfile     # 3 taps, 43 formulae, 26 casks
stow $(ls -d */ | grep -vE '^(zsh-linux|hypr|waybar|swaync|swayosd|swappy|qt|gtk|system)/')

# Third-party taps require explicit trust before Homebrew will load them
brew trust --cask nikitabobko/tap/aerospace
brew trust --cask docker/tap/sbx
brew trust --formula dotenvx/brew/dotenvx

mise install                      # node versions from mise/.config/mise/config.toml
```

## Bootstrap a new Linux box (Debian / Kali)

The Brewfile does not apply. Homebrew is not used on Linux; everything comes
from apt, a vendor apt repo, or a release binary dropped in `~/.local/bin`.

```bash
git clone git@github.com:phrabos/dotfiles.git ~/dotfiles
cd ~/dotfiles

# Kali ships its own ~/.zshrc and ~/.zprofile as real files. Stow refuses to
# overwrite them, so move them aside first.
mkdir -p ~/.config/kali-shell-defaults.bak
mv ~/.zshrc ~/.zprofile ~/.config/kali-shell-defaults.bak/ 2>/dev/null

stow $(ls -d */ | grep -vE '^(zsh-macos|aerospace|system)/')

# Antidote is not packaged in Debian.
git clone --depth=1 https://github.com/mattmc3/antidote.git ~/.antidote
```

`aerospace` is a macOS window manager; skip it. Its Linux counterpart is the
`hypr` package (plus `waybar` and `swaync`), which mirrors the AeroSpace
keybindings under Hyprland. See [LINUX.md](LINUX.md) for the
package-by-package translation of the Brewfile and the tools that need a
vendor repo or release binary.

### Debian binary name shims

Debian renames two binaries to avoid clashes with unrelated packages. The
configs here call them by their upstream names, so `~/.local/bin` carries
shims (this is why `.zprofile` puts it ahead of `/usr/bin`):

```bash
ln -sf "$(command -v batcat)" ~/.local/bin/bat
ln -sf "$(command -v fdfind)" ~/.local/bin/fd
```

Regenerate the Brewfile after installing or removing anything:

```bash
brew bundle dump --force --file=./Brewfile
```

## Daily use

```bash
stow <package>      # link one package
stow -D <package>   # UNlink (repo untouched — fully reversible)
stow -R <package>   # restow, after renaming files
stow -n -v <pkg>    # dry run, shows every link without making one

# link all — note the platform exclusion, see "Platform split" above
stow $(ls -d */ | grep -vE '^(zsh-linux|hypr|waybar|swaync|swayosd|swappy|qt|gtk|system)/')    # macOS
stow $(ls -d */ | grep -vE '^(zsh-macos|aerospace|system)/')           # Linux
```

Use `$(...)` and not a shell variable: zsh does not word-split unquoted
parameter expansions, so `PKGS=$(...); stow $PKGS` passes the whole list to
stow as a single package name and fails. Command substitution does split.

Stow refuses to overwrite a real file. If it errors, move the existing file
into the matching package here first, then stow.

## Packages

| Package | Links to |
|---|---|
| `zsh` | `.zshenv` `.zsh_plugins.txt`, `.config/zsh/` |
| `zsh-macos` | `.zshrc` `.zprofile` (macOS only) |
| `zsh-linux` | `.zshrc` `.zprofile` (Linux only) |
| `git` | `.gitconfig`, `.config/git/ignore` |
| `aerospace` | `.aerospace.toml` (macOS only) |
| `hypr` | `.config/hypr/` (Linux only) |
| `waybar` | `.config/waybar/` (Linux only) |
| `swaync` | `.config/swaync/` (Linux only) |
| `system` | **not stowed**: root-owned files under `/etc`, installed with `sudo install` (Linux only, see LINUX.md) |
| `gtk` | `.config/gtk-3.0/`, `.config/gtk-4.0/` (Linux only) |
| `qt` | `.config/qt6ct/` - Catppuccin palette for Qt 6 apps (Linux only) |
| `swayosd` | `.config/swayosd/` - volume / brightness popup (Linux only) |
| `swappy` | `.config/swappy/config` - screenshot annotation (Linux only) |
| `nvim` | `.config/nvim/` (LazyVim) |
| `zellij` | `.config/zellij/` |
| `ghostty` | `.config/ghostty/` |
| `starship` | `.config/starship.toml` |
| `atuin` | `.config/atuin/config.toml` |
| `btop` | `.config/btop/` |
| `bat` | `.config/bat/config` |
| `eza` | `.config/eza/theme.yml` |
| `lazygit` | `.config/lazygit/` |
| `mise` | `.config/mise/` |
| `posting` | `.config/posting/`, `.local/share/posting/` |
| `worktrunk` | `.config/worktrunk/config.toml` |
| `gh` | `.config/gh/config.yml` |
| `bin` | `.local/bin/` |
| `vim` | `.vimrc` |

Theme is Catppuccin Mocha across nvim, zellij, lazygit, btop, bat, eza,
starship, atuin, posting, and ghostty.

## Machine-local settings

Two things are deliberately left out of version control and must be set per
machine after cloning:

- **Git identity** — `.gitconfig` includes `~/.gitconfig.local`, which is not in
  this repo. Create it:

  ```bash
  cat > ~/.gitconfig.local <<'EOF'
  [user]
  	name = Your Name
  	email = you@example.com
  EOF
  ```

- **Zellij `default_cwd`** is deliberately not set in
  `zellij/.config/zellij/config.kdl`. It only takes a literal absolute path
  (Zellij expands neither `~` nor `$HOME` there), and `/home` vs `/Users`
  means no single value works on both machines. Pass it at launch instead:
  `zellij options --default-cwd "$HOME/Projects"`. The default layout does not
  depend on it: layout `cwd` values do expand `~`, so its panes open in the
  right place wherever Zellij is started.

  `~/Projects` has a capital `P`: ext4 on Linux is case-sensitive and Kali
  registers `~/Projects` as `XDG_PROJECTS_DIR`. The macOS folder is
  `~/projects`, but APFS is case-insensitive, so `~/Projects` resolves there
  too.

AeroSpace's `workspace-to-monitor-force-assignment` also names specific
displays; adjust or delete those lines for your setup.

## Deliberately NOT in this repo

Credentials and machine state. These stay as real files in `~/.config`,
unlinked and untracked:

| Path | Why |
|---|---|
| `~/.gitconfig.local` | git identity (name, email) |
| `.config/gh/hosts.yml` | GitHub auth token |
| `.config/gcloud/` | GCP credentials (~91 MB) |
| `.config/configstore/firebase-tools.json` | Firebase OAuth refresh/access tokens |
| `.config/firebase/` | GCP application default credentials |
| `.config/atuin/atuin-receipt.json` | licensing artifact |
| `.config/worktrunk/approvals.toml` | per-machine record of which project-hook commands were reviewed and approved. Committing it would make a fresh clone execute them without asking. |
| `.config/worktrunk/approvals.toml.lock` | lock file |
| `.claude/` | credentials plus ~200 MB of session state |
| `.config/openspec/` | self-rewriting; carries a machine-specific telemetry UUID |

## Self-rewriting configs

Some tools overwrite their own config on exit, which fights version control.
Check before adding a new package.

- **btop** — fixed in-file with `save_config_on_exit = false`. Do not set this
  back to `true`, and quit btop before editing `btop.conf` by hand; a running
  instance writes its in-memory state over your edits on exit.
- **openspec** — not fixable in-file, so it is excluded entirely. Telemetry is
  disabled via `DO_NOT_TRACK=1` in `.zshenv`, not via its config. After a fresh
  clone, run `openspec config profile` to restore profile/delivery/workflows.

## Manual steps after cloning

Not automatable — these need interactive auth or a browser:

```bash
gh auth login
gcloud auth login
firebase login
atuin login          # then: atuin sync
openspec config profile
```

Also: grant AeroSpace accessibility permissions in System Settings, and set the
Ghostty font if IosevkaTerm Nerd Font hasn't finished installing from the cask.

## Notes

- Node is managed by **mise** (not nvm), with **corepack** providing per-project
  pnpm from each `package.json`'s `packageManager` field. Never `npm i -g pnpm`.
- Python interpreters come from **uv**; project venvs use absolute paths, so
  there is no PATH contest to manage.
- `.zshenv` is sourced by *every* zsh, including non-interactive and `ssh host cmd`.
  PATH entries there are guarded against duplicate prepending in subshells.
