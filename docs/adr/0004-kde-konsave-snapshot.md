# ADR-0004: KDE configs as a konsave snapshot, stable files through stow

**Status:** Superseded by ADR-0007
**Date:** 2026-10-01
**Deciders:** leitosama

## Context

For KDE only two of the three moments in CLAUDE.md matter: **save** the desktop before leaving
a machine and **bootstrap** it on a new one. Rolling single fixes out to running desktops is not
needed; there are one or two KDE machines and they look the same (same monitors, same panels).

History: 2023-11 → 2025-08 the KDE configs were a konsave profile applied by `konsave.yaml`
with `konsave -a` on every run, so every run wiped local settings, and saving meant copying
`~/.config/konsave` back into the repo by hand. In 2025-08 it was replaced by `gui.yaml`,
which deleted `~/.config/<file>` and symlinked it into `gui_config/` in the clone.

Symlinks turned out to be a poor fit for KDE:

- Plasma and KDE apps keep writing runtime state into the same rc files (window sizes,
  recent files, panel and applet IDs, per-output keys), so every click becomes a diff.
- KConfig saves through a temp file and a rename, which can replace the link with a regular
  file and silently cut it off the repo.
- The old `gui.yaml` also cloned `dev` with `update: true` and deleted files before linking,
  against ADR-0002.

## Decision

- KDE settings are a **konsave snapshot** in `konsave/` (`conf.yaml` lists what is saved,
  `profiles/leito/` is the snapshot). `~/.config/konsave` is a link to that directory, so
  `konsave -s leito -f` writes straight into the clone and saving is `git diff` + commit.
  Applying copies files, it never links them.
- `gui.yaml` applies the snapshot (`konsave -a leito`) **once per machine**, recorded by
  `~/.local/state/dotfiles/konsave-applied`; later runs leave KDE settings alone unless
  `-e kde_apply=true` is passed.
- Files that KDE only writes when you edit them on purpose (konsole profiles and color
  schemes) are the `kde` stow package and are linked like the CLI configs.
- `gui.yaml` uses the same clone on `main` and the same stow call as `cli.yaml`
  (shared `tasks/dotfiles_clone.yaml` and `tasks/stow.yaml`). This closes the Known issue
  from CLAUDE.md and action item 2 of ADR-0001.
- Only settings are versioned: no themes, icons, fonts or wallpapers.

`~/.config/konsave` is linked as one directory, unlike stow's `--no-folding`: konsave keeps
nothing machine-local there, and `konsave -s` must be able to add new files to the profile,
which per-file links would leave outside the clone.

## Options Considered

### Option A: konsave snapshot + stow for stable files (chosen)

| Dimension | Assessment |
|-----------|------------|
| Complexity | Low: one pipx tool, one link, one marker file |
| Portability | Any KDE Plasma (5 and 6); the playbook is Fedora-only anyway |
| Maintenance | Low: konsave 2.3.0 (2026-01) is maintained again |
| Familiarity | Already used here in 2023–2025 |

**Pros:** save and apply are one command each; copies, so KDE's own writes never touch the
clone between saves; the diff after a save shows real changes only.
**Cons:** apply overwrites whole files (no merging); a file dropped from `conf.yaml` stays in
the profile until removed by hand; panels (`appletsrc`) only carry over between identical setups.

### Option B: keep symlinks from `gui_config/` (status quo)

| Dimension | Assessment |
|-----------|------------|
| Complexity | Low |
| Portability | Same |
| Maintenance | High: runtime noise in git, links cut by KConfig rewrites |
| Familiarity | Plain Ansible |

**Pros:** no extra tool; edits land in the clone immediately.
**Cons:** see Context.

### Option C: own copy script (`copy force: false` + a `kde-save` script)

| Dimension | Assessment |
|-----------|------------|
| Complexity | Med: the same copy/save logic, written and kept here |
| Portability | Same |
| Maintenance | Med |
| Familiarity | Plain Ansible + shell |

**Pros:** no external tool.
**Cons:** re-implements konsave with the same semantics.

### Option D: declarative keys with `kwriteconfig6` (and `layout.js` for panels)

| Dimension | Assessment |
|-----------|------------|
| Complexity | Med/High: every setting is found and written as group/key/value |
| Portability | Plasma 6 |
| Maintenance | Med |
| Familiarity | KDE's own CLI |

**Pros:** merges with local settings, idempotent, clean diffs; the right tool for rolling out
single fixes.
**Cons:** saving is manual (find which keys changed); roll out is not needed for now.

### Option E: plasma-manager (Nix + Home Manager)

| Dimension | Assessment |
|-----------|------------|
| Complexity | High: Nix and Home Manager on Fedora |
| Portability | Anywhere Nix runs |
| Maintenance | Low once set up; actively maintained |
| Familiarity | New language and package manager |

**Pros:** the most complete declarative KDE setup; `rc2nix` helps with saving.
**Cons:** a second package manager next to Ansible; rejected by the owner.

A Global Theme (Look-and-Feel package) applied with `plasma-apply-lookandfeel` was also
considered: it covers only the visual part, so it could complement A but not replace it.

## Trade-off Analysis

With bootstrap and save as the only moments, a snapshot of whole files is exactly the model
needed, and konsave already implements it. D and E pay for merging and roll out, which is not
needed now. The original konsave problems came from how it was wired (apply on every run, a
second copy of the profile), not from konsave itself; the link and the marker fix both.

## Consequences

- Easier: saving the desktop (`konsave -s leito -f`, review `git diff`, commit); bootstrap.
- Harder: rolling one settings change out to a running desktop (`-e kde_apply=true` resets
  all listed files to the snapshot).
- Revisit: if machines start to differ (monitors, panels) or roll out becomes needed, move
  the affected settings to Option D.

## Action Items

1. [x] Move `gui_config/kde_dotconfig` into the konsave profile, konsole files into `stow/kde`.
2. [x] `gui.yaml`: clone on `main`, shared clone/stow tasks, konsave install, link, apply once.
3. [ ] Check on a Fedora KDE VM: bootstrap, rerun without changes, save, `kde_apply=true`.
