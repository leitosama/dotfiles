# ADR-0003: Zi as the zsh plugin manager (replaces antigen)

**Status:** Accepted
**Date:** 2025-09-30 (recorded 2026-10-01)
**Deciders:** leitosama

## Context

Zsh plugins (autosuggestions, syntax highlighting, fzf integration) were loaded with antigen,
installed by the playbook as a single file pinned to a commit (`antigen.zsh@8846aa9`).
Antigen is effectively unmaintained (last release v2.2.3, 2018), the pin had to be bumped by hand, and completion
setup (`compinit`) was handled separately, which caused trouble with large generated
completions such as `oc` (a 22k-line `oc.completion.zsh` was committed to the repo).

The decision was made in commit `9655e54` ("antigen → zi + fix oc compinit"). The rationale
below is reconstructed from the code and history; correct it if the original reasons differ.

## Decision

Use [Zi](https://github.com/z-shell/zi):

- The playbook fetches Zi's installer and runs it with `-i skip` (don't edit `.zshrc`, which
  the repo manages) and `ZI_HOME=~/.zi`, guarded by `creates: ~/.zi/bin/zi.zsh`.
- `zshrc` loads plugins with `zi light …` and initialises completion with `zicompinit`, after
  the repo's completions manager has put its directory on `fpath`.
- The committed `oc.completion.zsh` was dropped. Later (`6b03fe7`) tool completions moved to
  `completions.zsh`, which generates them into `~/.local/share/zsh/completions` on `fpath`.

## Options Considered

### Option A: Zi (chosen)

| Dimension | Assessment |
|-----------|------------|
| Complexity | Low: installer + a few `zi light` lines |
| Portability | Any system with zsh and git |
| Maintenance | Active project; plugins update with `zi update` |
| Familiarity | Successor of zinit, same syntax |

**Pros:** maintained; turbo/lazy loading available; `zicompinit` integrates completion init.
**Cons:** installer is fetched from the network on each run (a remote script); its CLI changed
over time (`-y` was dropped, default path moved to `~/.local/share/zi`), which broke the
playbook once (fixed in `85dd02e` by pinning `ZI_HOME` and dropping `-y`).

### Option B: Keep antigen

| Dimension | Assessment |
|-----------|------------|
| Complexity | Low |
| Portability | Good |
| Maintenance | Unmaintained upstream, manual pin bumps |
| Familiarity | Known |

**Pros:** no migration.
**Cons:** unmaintained upstream, manual pin bumps, completion handling left to us.

### Option C: Plain `git clone` of plugins + `source` (no manager)

| Dimension | Assessment |
|-----------|------------|
| Complexity | Low for three plugins |
| Portability | Good |
| Maintenance | Updates are on us (Ansible `git` tasks) |
| Familiarity | Trivial |

**Pros:** nothing to install, fully reproducible with pinned commits.
**Cons:** every plugin becomes a playbook task; no lazy loading.

### Option D: Other managers (oh-my-zsh, antidote, sheldon)

**Pros:** antidote/sheldon are fast and maintained; oh-my-zsh is ubiquitous.
**Cons:** oh-my-zsh is a framework, not just a loader; sheldon needs a Rust binary per
platform; antidote was not evaluated at the time.

## Trade-off Analysis

The plugin set is small, so the manager matters mostly for maintenance and startup time.
Zi keeps the `zshrc` short and is maintained; the cost is depending on a network installer
whose flags can change. That risk is contained by `creates:` (installer runs only once per
machine) and by the comments documenting the flags.

## Consequences

- Easier: adding a plugin is one `zi light` line in `zshrc`; no plugin tasks in Ansible.
- Harder: first run needs network access to GitHub; installer changes can break bootstrap.
- Revisit: pin the installer to a commit instead of `refs/heads/main` if it breaks again.

## Action Items

1. [x] Replace antigen with Zi in the playbook and `zshrc`.
2. [x] Fix installer flags and `ZI_HOME` (`85dd02e`).
3. [x] Remove leftover antigen lines (`4bf6220`).
