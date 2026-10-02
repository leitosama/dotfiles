# dotfiles
My configuration files

Why things are done this way: [docs/adr](docs/adr). Notes for AI agents: [CLAUDE.md](CLAUDE.md).

## How it works

- The playbook keeps one clone on the host, `~/.dotfiles` (branch `main`), and links configs
  from it with [GNU Stow](https://www.gnu.org/software/stow/): every directory in [`stow/`](stow)
  is a package mirroring `$HOME`, e.g. `stow/zsh/.config/zsh/zshrc` → `~/.config/zsh/zshrc`.
  Editing a linked file edits the clone: check `git diff` and commit what you want to keep.
- The clone is only cloned when missing and fast-forwarded when it is clean and on `main`.
  Local changes, other branches and unpushed commits are left alone (the run reports it),
  merging them is up to you and git.
- `~/.zshrc` is not linked: it is a stub created once that sources `~/.config/zsh/zshrc`.
  Whatever installers append to it stays machine-local; move what you want to keep into
  the repo by hand.
- A new file goes into a package under `stow/`; a new package also goes to `stow_packages`
  in [`cli.yaml`](cli.yaml). Stow never overwrites: if a real file is already in
  place the run fails, remove it or merge it into the repo with `stow --adopt` + `git diff`.

## Running

Locally, from the clone itself (what you edit is what gets applied):

```sh
git clone https://github.com/leitosama/dotfiles.git ~/.dotfiles
ansible-playbook -i localhost, -c local -K ~/.dotfiles/cli.yaml
```

With cloud-init or any other bootstrap, `ansible-pull`; with `-d ~/.dotfiles` its checkout is
reused, otherwise the playbook makes its own clone in `~/.dotfiles` (as the user it runs as):

```sh
ansible-pull -U https://github.com/leitosama/dotfiles.git -C main -d ~/.dotfiles cli.yaml
```

On a remote host the playbook clones/updates `~/.dotfiles` from GitHub, so push first:

```sh
git push                                  # the host only gets what is on origin/main
ansible-playbook -i host, -K cli.yaml
```

To bring edits made on the host back: commit and push them there, or
`ssh host git -C .dotfiles diff | git apply` locally.

## KDE desktop (Arch, Fedora)

[`gui.yaml`](gui.yaml) installs KDE and its apps on top of the CLI setup and sets up the
desktop ([ADR-0007](docs/adr/0007-kde-global-theme-and-settings-keys.md)):

- **Theme**: One Dark Pro Night Flat on Breeze, Papirus-Dark icons. The color scheme and
  the Konsole scheme are in the [`kde`](stow/kde) stow package (with the konsole profiles).
- **Global Theme** [`leito`](lookandfeel/leito): the same theme defaults plus the panel layout
  as a [Plasma script](lookandfeel/leito/contents/layouts/org.kde.plasma.desktop-layout.js).
  Linked as a whole directory to `~/.local/share/plasma/look-and-feel/leito`.
- **Settings**: a short list of keys (`kde_settings` in `gui.yaml`: theme, Night Color,
  KRunner on Meta, tiling gap) written with `kwriteconfig6` on every run, only where the value
  differs. Everything else stays local to the machine (file associations, mouse, wallpaper).
- Plasma and the apps that talk to the session or the host (konsole, dolphin, spectacle,
  kdeconnect, kwalletmanager, kleopatra, filelight, Kontact and the rest of PIM) are distro
  packages. Standalone apps (okular, gwenview, kate, haruna, elisa, kdiff3…, the full list is
  `kde_flatpak_apps` in `gui.yaml`) are user flatpaks from Flathub, so on a rolling distro their
  version doesn't follow Qt/KDE Frameworks upgrades ([ADR-0006](docs/adr/0006-gui-distro-agnostic-flatpak-apps.md)).
  Another distro needs its KDE packages in `kde_desktop` in `gui.yaml`.

Rolling back and holding a flatpak app (here Okular):

```sh
flatpak remote-info --user --log flathub org.kde.okular   # find the commit to go back to
flatpak update --user --commit=<commit> org.kde.okular
flatpak mask --user org.kde.okular                        # skip it in `flatpak update`
flatpak mask --user --remove org.kde.okular               # follow updates again
```

```sh
ansible-playbook -i localhost, -c local -K ~/.dotfiles/cli.yaml   # CLI first
ansible-playbook -i localhost, -c local -K ~/.dotfiles/gui.yaml
```

After a run that changed settings, log out and back in: Plasma applies the color scheme at
login (and again whenever the `.colors` file changes). Edit colors in the repo, not in System
Settings, which saves a copy instead of writing through the link.

Panels live in the Global Theme's layout script. Plasma's own `dumpCurrentLayoutJS` (the
call behind the Look and Feel Explorer) saves them; two scripts from the `kde` stow package
wrap it:

```sh
kde-panels-save          # current panels -> the layout script in ~/.dotfiles, shows the diff
kde-panels-save --push   # same, then commit and push (before leaving a machine)
kde-panels-load          # replace the current panels with the saved ones (theme and wallpaper stay);
                         # lists widgets missing on this machine: install them and run it again
```

On load, widgets that are not installed and apps that don't exist on the machine are
skipped. Saving drops desktops, wallpapers and machine-local keys (popup sizes, cached
launcher copies, anything with a path in `$HOME`). A new user gets the panels at first login;
on a machine where Plasma already made its default panels, run `kde-panels-load` once.

## Zsh PATH and completions

### PATH

[`path.zsh`](stow/zsh/.config/zsh/path.zsh) appends directories from two lists:

- [`path.list`](stow/zsh/.config/zsh/path.list): public, committed.
- `~/.config/zsh/path.local.list`: private, machine-local, never in the repo.

```sh
path-add ~/yandex-cloud/bin     # public list
path-add -p ~/work/secret/bin   # private list
path-rm ~/work/secret/bin
```

### Completions

[`completions.zsh`](stow/zsh/.config/zsh/completions.zsh) keeps completion scripts in
`~/.local/share/zsh/completions` (on `fpath`), so no per-tool lines in `.zshrc` are needed.

- Any `_<cmd>` file put there is picked up.
- Tools that print their own completion script are listed in
  [`completions.list`](stow/zsh/.config/zsh/completions.list). Scripts are generated on
  shell start and regenerated when the binary gets upgraded. Missing tools are skipped.

```sh
comp-add oc                                    # runs `oc completion zsh`
comp-add helm helm completion zsh              # custom generator
comp-add foo cat ~/foo/completion.zsh.inc      # ready-made script
comp-add vault @complete-c                     # binary completes itself (see below)
comp-update [cmd...]                           # force regeneration
comp-rm foo
```

Tools built on [posener/complete](https://github.com/posener/complete) (HashiCorp's `terraform`,
`vault`, `consul`, `nomad`, `packer`, ...) have no completion script: `-install-autocomplete`
appends `complete -C <binary>` to `~/.zshrc`, and the binary prints candidates itself.
Register them with `@complete-c` instead of running `-install-autocomplete`
(if already run, undo with `<cmd> -uninstall-autocomplete`).
