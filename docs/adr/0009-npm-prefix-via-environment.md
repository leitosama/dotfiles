# ADR-0009: npm global prefix via environment, not a stow package

**Status:** Proposed
**Date:** 2026-10-07
**Deciders:** leitosama

## Context

`npm install -g` needs a user-writable prefix; the distro default (`/usr`, `/usr/local`) needs
root for every global install. The usual fix is a prefix under `$HOME` (here `~/.npm-global`,
with `~/.npm-global/bin` added to PATH via `path.list`).

The natural place to put `prefix = ~/.npm-global` is `~/.npmrc`. But npm treats that file as
read-write state, not just input: `npm config set` edits it, and `npm login` writes auth tokens
into it. That is exactly the kind of file ADR-0002 and the `~/.zshrc` stub avoid linking into
the clone: a stow symlink would turn every `npm login` on any machine into an edit of
`~/.dotfiles`, with credentials one `git push` away from GitHub. Unlike `.zshrc`, npmrc has no
include/source directive, so there is no stub to redirect writes elsewhere.

## Decision

Set `NPM_CONFIG_PREFIX=$HOME/.npm-global` as a plain export in
`stow/zsh/.config/zsh/zshrc`. No `stow/npm/` package, no linked npmrc anywhere. `~/.npmrc`
stays whatever npm makes of it on each machine, including tokens, and is never read by this
repo.

## Options Considered

### Option A: Stow package, XDG userconfig path

Link `stow/npm/.config/npm/npmrc` → `~/.config/npm/npmrc` and point npm at it with
`export NPM_CONFIG_USERCONFIG="$HOME/.config/npm/npmrc"` (npm supports this since it reads
`NPM_CONFIG_*` env vars for any config key, including which file is the "user" config).

| Dimension | Assessment |
|-----------|------------|
| Complexity | Low: one more stow package, same shape as `kde`/`zsh` |
| Portability | Any OS with npm |
| Maintenance | None once set up |
| Familiarity | Mirrors how every other stow package in this repo works |

**Pros:** one file to hold several npm settings (registry, `init-author-*`, `fund=false`, …) if
they ever accumulate; consistent with "a new config file goes into a package under `stow/`".
**Cons:** `npm login` still writes to `NPM_CONFIG_USERCONFIG`, so the token problem does not go
away, it only moves to a path that is more obviously "the repo's file" — someone adopting the
file with `stow --adopt` or editing it by hand could commit a token without `~/.npmrc`'s
usual expectation of being private. Needs a warning comment in the file and care at adoption
time. A package for exactly one key (`prefix`) is also more machinery than the setting
deserves right now.

### Option B: `NPM_CONFIG_PREFIX` in `zshrc`, no npm stow package (chosen)

| Dimension | Assessment |
|-----------|------------|
| Complexity | Minimal: one export line |
| Portability | Any OS with npm; harmless if npm isn't installed |
| Maintenance | None |
| Familiarity | Same pattern as other `NPM_CONFIG_*`/`XDG_*` env vars already in `zshrc` |

**Pros:** the only thing versioned is the prefix path, which carries no secret; `~/.npmrc`
keeps doing what npm expects of it (private, machine-local, holds tokens) without the repo
touching it at all; zero adoption risk.
**Cons:** no repo-tracked place for future non-secret npm settings; if more than the prefix is
ever wanted, falls back to Option A for those keys (or a second, carefully scoped env var).

### Option C: Keep installing global packages as root (`sudo npm install -g`)

**Pros:** nothing to configure.
**Cons:** every global install needs a password, is easy to forget on a new machine, and mixes
root-owned files into `/usr`. Rejected as the status quo this ADR moves away from.

## Trade-off Analysis

The deciding factor is where npm's *writes* land, not where its *config* lives. Option A keeps
all npm settings in one versioned file but inherits the login-token problem that ADR-0002
already ruled out for `.zshrc`, with no stub mechanism to redirect writes. Option B accepts a
less centralized setup (one `export` instead of one file) in exchange for the repo never being
in the path of an npm write. Since there is currently exactly one setting to carry, that trade
is worth it.

## Consequences

- Global npm packages install without root, under `~/.npm-global`, on any machine that sources
  this repo's `zshrc` and has `~/.npm-global/bin` on PATH (`path.list`).
- `~/.npmrc`, including anything `npm login` puts there, is never read, linked, or committed by
  this repo.
- No per-OS npm/nodejs install step was added to `cli.yaml`: package names diverge
  (`nodejs-npm` on Fedora, `npm` on Arch/Debian, `node` via Homebrew on Darwin) and node is not
  core to the shell setup this repo manages. `NPM_CONFIG_PREFIX` is inert when npm is absent.
- Revisit if a second non-secret npm setting is needed (e.g. `registry`, `fund=false`): switch
  to Option A — `stow/npm/.config/npm/npmrc` + `export NPM_CONFIG_USERCONFIG=…`, add `npm` to
  `stow_packages` in `cli.yaml` — and add a "no tokens here" comment at the top of that file,
  since `npm login` would then write through the symlink into the clone.

## Action Items

1. [x] `export NPM_CONFIG_PREFIX="$HOME/.npm-global"` in `stow/zsh/.config/zsh/zshrc`.
2. [x] `~/.npm-global/bin` in `stow/zsh/.config/zsh/path.list`.
3. [x] No `stow/npm/` package, no `npm` in `stow_packages`.
