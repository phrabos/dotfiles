# dotfiles

Managed with [GNU Stow](https://www.gnu.org/software/stow/). Each top-level
directory is a "package" whose contents mirror the path relative to `$HOME`.

```
dotfiles/zsh/.zshrc              ->  ~/.zshrc
dotfiles/nvim/.config/nvim/      ->  ~/.config/nvim/
```

The files in `$HOME` are **symlinks into this repo**, so editing `~/.zshrc`
edits `zsh/.zshrc` here. One file, two paths — no sync step, no drift.

## Bootstrap a new Mac

```bash
xcode-select --install
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

git clone git@github.com:phrabos/dotfiles.git ~/dotfiles
cd ~/dotfiles

brew bundle --file=./Brewfile     # 3 taps, 43 formulae, 26 casks
stow */                           # symlink everything

# Third-party taps require explicit trust before Homebrew will load them
brew trust --cask nikitabobko/tap/aerospace
brew trust --cask docker/tap/sbx
brew trust --formula dotenvx/brew/dotenvx

mise install                      # node versions from mise/.config/mise/config.toml
```

Regenerate the Brewfile after installing or removing anything:

```bash
brew bundle dump --force --file=./Brewfile
```

## Daily use

```bash
stow <package>      # link one package
stow */             # link all
stow -D <package>   # UNlink (repo untouched — fully reversible)
stow -R <package>   # restow, after renaming files
stow -n -v */       # dry run, shows every link without making one
```

Stow refuses to overwrite a real file. If it errors, move the existing file
into the matching package here first, then stow.

## Packages

| Package | Links to |
|---|---|
| `zsh` | `.zshrc` `.zprofile` `.zshenv` `.zsh_plugins.txt` |
| `git` | `.gitconfig`, `.config/git/ignore` |
| `aerospace` | `.aerospace.toml` |
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

- **Zellij `default_cwd`** — hardcoded to `/Users/phrabos/projects` in
  `zellij/.config/zellij/config.kdl`. Zellij 0.44 expands neither `~` nor
  `$HOME` and silently ignores the setting if you use either, so a literal
  absolute path is the only form that works. Edit it for your machine.

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
