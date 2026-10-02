# CLAUDE.md

Personal dotfiles of leitosama, applied with Ansible. Read this before changing anything;
user-facing usage lives in [README.md](README.md), the reasons behind the layout in
[docs/adr/](docs/adr).

## Why this repo exists

1. **A predictable terminal on any UNIX/Linux box**: same shell, prompt, plugins, PATH and
   completions on a laptop, a server or a fresh VM (Linux distros and macOS).
2. **CLI and GUI kept in sync**: terminal configs and the KDE desktop are both versioned here.
3. It is used in three moments, so every change must keep them working:
   - **bootstrap** a new machine (one command, possibly `ansible-pull` from cloud-init);
   - **save** before moving off a machine: whatever was edited locally gets committed back;
   - **roll out** a fix to machines that already run it (rerun the playbook, it must be
     idempotent and must not destroy local edits).

## Layout

| Path | What |
|------|------|
| `cli.yaml` | CLI playbook: any UNIX/Linux. Packages (zsh, git, vim, stow), starship, Zi, default shell, `~/.dotfiles` clone, stow links, `~/.zshrc` stub |
| `gui.yaml` | GUI playbook: KDE on Linux (Arch, Fedora; per-`os_family` lists). Plasma and session apps from the distro, end-user apps via user flatpak, the `kde` stow package, the `leito` Global Theme, `kde_settings` keys |
| `stow/<package>/` | GNU Stow packages mirroring `$HOME` (`stow/zsh/.config/zsh/zshrc` → `~/.config/zsh/zshrc`) |
| `tasks/` | Tasks shared by both playbooks: clone/update `~/.dotfiles`, stow |
| `lookandfeel/leito/` | Global Theme: theme defaults + panel layout script (Plasma JS); linked as one directory to `~/.local/share/plasma/look-and-feel/leito` |
| `docs/adr/` | Architecture Decision Records |
| `.github/workflows/lint.yml` | CI: `ansible-lint` + `ansible-playbook --syntax-check` |
| `.github/dependabot.yml`, `workflows/dependabot-auto-merge.yml` | Dependency updates, see [ADR-0005](docs/adr/0005-dependabot-and-claude-action.md), [ADR-0008](docs/adr/0008-drop-claude-action.md) |
| `requirements.txt` | Python deps for running and linting (`ansible`, `ansible-lint`) |

## How the CLI playbook works (invariants)

See [ADR-0002](docs/adr/0002-gnu-stow-single-clone.md) for the reasoning.

- **One clone, `~/.dotfiles`, branch `main`**, is the only copy of the configs on a host.
  Stow links point into it, so editing a linked file edits the clone.
- The clone is **never reset**: cloned only when missing, then fast-forwarded only when it is
  clean and on `main`. Otherwise the run prints `SKIP: …` and leaves it alone. Do not add
  `force: true`, `git reset`, `update: true` or anything that can drop local commits or edits.
- Stow runs with `--no-folding --restow`: it links files, never whole directories, so
  machine-local files (e.g. `~/.config/zsh/path.local.list`) never land in the clone.
- **`~/.zshrc` is not managed**: it is a stub created once (`force: false`) that sources
  `~/.config/zsh/zshrc`. Installers append to it freely; that stays machine-local.
  The playbook refuses to run if `~/.zshrc` is a symlink (old layout).
- Stow never overwrites real files: a conflict fails the run on purpose.
- `become` only where root is needed (packages, starship to `/usr/local/bin`, `chsh`);
  everything in `$HOME` runs as the user.

## Common changes

- **New config file** → put it in a package under `stow/` mirroring its `$HOME` path.
- **New package** → new `stow/<name>/` dir and add `<name>` to `stow_packages` in `cli.yaml`
  (or in `gui.yaml` for desktop-only packages, like `kde`).
- **New CLI tool to install** → `cli.yaml`; keep it OS-agnostic (`ansible.builtin.package`,
  Darwin has no `become`) or guard it with `when:` on `ansible_facts`.
- **GUI/KDE change** → `gui.yaml` (Arch and Fedora: `ansible.builtin.package`, distro differences
  in the per-`os_family` maps). A new KDE app goes to `kde_flatpak_apps` if it is standalone, to
  `kde_distro_apps` if the sandbox breaks it (host services, gpg, disk access), see
  [ADR-0006](docs/adr/0006-gui-distro-agnostic-flatpak-apps.md). KDE settings are keys, not
  files ([ADR-0007](docs/adr/0007-kde-global-theme-and-settings-keys.md)): add
  `{file, group, key, value}` to `kde_settings` in `gui.yaml` (find it with `kreadconfig6` or a
  diff of `~/.config` before/after the change). Theme keys also go to
  `lookandfeel/leito/contents/defaults`. Panels are the layout script in
  `lookandfeel/leito/contents/layouts/`: its `var layout` block is written by `kde-panels-save`
  (never by hand), `kde-panels-load` applies it; the code around the block filters out
  widgets and apps missing on the machine.
  Apps you don't want from the distro (games, bundled extras) go to `kde_unwanted_apps` in
  `gui.yaml`, one list with the reason in a comment: excluded from Fedora's group and removed.
  Never symlink rc files that Plasma rewrites and never version whole rc files (they carry
  machine data: file dialog history, desktop file names, bookmarks); only files KDE writes on
  explicit edits (color schemes, konsole profiles) go to `stow/kde/`. The Global Theme is linked
  as a directory because KPackage ignores per-file links that point outside the package.
- **New zsh plugin** → `zi light …` in `stow/zsh/.config/zsh/zshrc` (see [ADR-0003](docs/adr/0003-zi-zsh-plugin-manager.md)).
- **PATH / completions** → `path-add` / `comp-add` helpers, lists in `stow/zsh/.config/zsh/`
  (details in README).
- **An architectural decision** (new tool, new layout, dropping something) → write an ADR,
  see [docs/adr/README.md](docs/adr/README.md).

## Testing

Linting is the test suite. Run before every push:

```sh
pip install -r requirements.txt
ansible-lint
ansible-playbook -i localhost, --syntax-check cli.yaml gui.yaml
```

CI runs the same on every push and PR (`.github/workflows/lint.yml`). Lint config is in
`.ansible-lint` (profile `production`, `strict: true`: warnings fail too). CI also sets
`ANSIBLE_INJECT_FACTS_AS_VARS=false`, the future ansible-core default, so use
`ansible_facts['env']['HOME']`, never `ansible_env.HOME` or `ansible_os_family`. Fix findings instead of silencing them; a `# noqa`
needs a comment explaining why.

Never run the playbooks against the machine you are working on as a "test": they change
the login shell, install packages and link files into `$HOME`.

## Dependencies

Dependabot (weekly, Friday) watches GitHub Actions, `requirements.txt` and `.devcontainer`.
Patch/minor PRs are auto-merged by `dependabot-auto-merge.yml` once Lint is green; majors wait
for review and are fixed by hand or in a Claude Code session (no Claude action, ADR-0008).
Not visible to Dependabot (nothing pinned, always latest): `stow`, Papirus and the other distro
packages, starship and Zi installers. Repo settings needed:
"Allow auto-merge" and Lint as a required check on `main` (no secrets).

## Conventions

- Fully qualified module names (`ansible.builtin.*`, `community.general.*`).
- Comments in playbooks explain *why* (non-obvious installer flags, stow flags, safety guards),
  not what the task name already says.
- Commit subjects are short and imperative; a `[zsh]`, `[gui]`, `[ansible]` prefix is common.
- English everywhere in the repo (docs, comments, commits).

## Known issues / planned work

- Rename `cli.yaml` → `cli.yaml` for symmetry with `gui.yaml`. Postponed (the owner will
  do it): it breaks existing `ansible-pull … cli.yaml` commands, update README with it.
