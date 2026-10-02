# ADR-0002: Link configs with GNU Stow from a single clone on `main`

**Status:** Accepted
**Date:** 2026-09-29 (recorded 2026-10-01)
**Deciders:** leitosama

## Context

The repo is used to bootstrap machines, to save local edits before leaving a machine and to
roll out fixes to machines already set up. Before this decision the CLI playbook mixed three
sources of configs:

- the `~/.dotfiles` clone, tracking a `dev` branch that no longer existed;
- files copied from the Ansible controller;
- symlinks to `playbook_dir`, which dangle on remote hosts and with `ansible-pull` temp dirs.

So on a host it was unclear which copy was live, edits made on a machine could not be
committed back reliably, and an update could reset local work. `~/.zshrc` was a symlink into
the repo, so whatever installers appended to it (conda, nvm, cloud SDKs) ended up as repo diffs.

## Decision

- One clone per host, `~/.dotfiles`, on branch `main`, is the only copy of the configs.
- Configs live in GNU Stow packages under `stow/<package>/`, mirroring `$HOME`, and are linked
  with `stow --no-folding --restow` (packages listed in `stow_packages`).
- The clone is created only when missing and updated only by `git pull --ff-only` when the
  working tree is clean and on `main`. Otherwise the run reports `SKIP` and changes nothing;
  merging is left to the user and git.
- `~/.zshrc` is a stub created once (`force: false`) that sources `~/.config/zsh/zshrc`.
  It is not in the repo; what installers append stays local.
- Stow never overwrites existing files: a conflict fails the run and is resolved by hand
  (`stow --adopt` + `git diff`).

## Options Considered

### Option A: GNU Stow from a single clone (chosen)

| Dimension | Assessment |
|-----------|------------|
| Complexity | Low: directory layout is the config |
| Portability | Stow is packaged on every Linux distro and Homebrew |
| Maintenance | Low: a new file needs no playbook change |
| Familiarity | Classic dotfiles tool |

**Pros:** editing a linked file edits the clone, so "save before moving" is `git commit`;
adding a file is just placing it; `--no-folding` keeps machine-local files out of the repo;
stow refuses to overwrite, so nothing is silently lost.
**Cons:** needs stow installed; conflicts with pre-existing files must be fixed by hand;
`--restow` output needs parsing for an honest `changed` status.

### Option B: Ansible `file: state=link` per file (what `gui.yaml` does)

| Dimension | Assessment |
|-----------|------------|
| Complexity | Med: every file listed in the playbook |
| Portability | Good |
| Maintenance | Med: list and repo drift |
| Familiarity | Plain Ansible |

**Pros:** no extra tool.
**Cons:** every new file is a playbook change; the "delete then link" pattern destroys real
files without asking.

### Option C: Copy/template files from the controller

| Dimension | Assessment |
|-----------|------------|
| Complexity | Low |
| Portability | Good |
| Maintenance | High: edits on the host are overwritten on next run |
| Familiarity | Plain Ansible |

**Pros:** templating, works without a clone on the host.
**Cons:** local edits can't flow back; the next rollout overwrites them.

### Option D: chezmoi / bare git repo in `$HOME`

| Dimension | Assessment |
|-----------|------------|
| Complexity | Med |
| Portability | Good |
| Maintenance | Med |
| Familiarity | New tool (chezmoi) or footgun-prone (bare repo) |

**Pros:** chezmoi has templating and secrets; bare repo has no links at all.
**Cons:** chezmoi applies copies, so edits go through `chezmoi edit/re-add`; a bare repo
makes all of `$HOME` a worktree. Both duplicate what Ansible + stow already do.

## Trade-off Analysis

The deciding requirement is that edits made on a machine flow back with plain git, and that
a rollout never destroys them. Links into one clone (A, B) satisfy the first; copies (C, D)
don't. Between A and B, stow makes the repo layout the single source of truth and refuses to
overwrite, while B needs a file list and deletes before linking. Fast-forward-only updates
trade "always latest" for "never lose work": a dirty or diverged clone is reported, not fixed.

## Consequences

- Easier: saving local changes (`git -C ~/.dotfiles diff`, commit, push); adding configs;
  reasoning about which copy is live.
- Harder: first run on a machine with existing configs (stow conflicts); a dirty clone stops
  receiving updates until the user commits or stashes.
- Revisit: `gui.yaml` still uses Option B and its own clone settings.

## Action Items

1. [x] Move configs from `config/` into `stow/zsh` and `stow/starship`.
2. [x] Replace `~/.zshrc` symlink with a stub; refuse to run over an old symlink.
3. [x] Document local, remote and `ansible-pull` runs in README.
4. [ ] Migrate `gui_config/` to stow packages and `gui.yaml` to the same clone policy.
