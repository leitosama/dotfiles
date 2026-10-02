# ADR-0001: Two Ansible playbooks: CLI and GUI

**Status:** Accepted; "GUI is Fedora-only" amended by ADR-0006
**Date:** 2025-08-04 (recorded 2026-10-01)
**Deciders:** leitosama

## Context

The repo has to make any UNIX/Linux machine (laptops, servers, VMs, Linux and macOS) get the
same terminal, and on the desktop also restore the KDE setup. Those targets differ a lot:

- The terminal part runs everywhere, often headless, sometimes without root for most steps,
  sometimes from cloud-init via `ansible-pull`.
- The desktop part only makes sense on one distro (Fedora) with KDE Plasma, needs `dnf`,
  flatpak and a graphical session, and touches many more files.

History: the repo started in 2023 as one Ansible playbook for Arch (`pacman`), with KDE configs
added through a separate `konsave.yaml` (konsave profiles). In 2025-03 KDE packages moved from
`cli.yaml` into `konsave.yaml`, and in 2025-08 konsave was replaced by `gui.yaml`, which
installs KDE + flatpak apps and links configs from `gui_config/` directly. The CLI playbook
went OS-agnostic (`pacman` → `ansible.builtin.package`) in 2025-02.

## Decision

Keep Ansible, with two independent playbooks in the repo root:

- `cli.yaml`: CLI, any UNIX/Linux, the default thing to run.
- `gui.yaml`: GUI, Fedora + KDE only, run additionally on desktops.

They share the `~/.dotfiles` clone but not tasks; each can be run alone.

## Options Considered

### Option A: Two playbooks, CLI and GUI (chosen)

| Dimension | Assessment |
|-----------|------------|
| Complexity | Low: two flat playbooks, no roles |
| Portability | CLI everywhere, GUI only where it applies |
| Maintenance | Low; GUI breakage can't block a server bootstrap |
| Familiarity | Plain Ansible |

**Pros:** a server never pulls KDE logic or `dnf`-only modules; CLI stays small enough for
`ansible-pull` from cloud-init; each playbook can make its own platform assumptions.
**Cons:** shared steps (clone, stow) are duplicated and can drift (see the GUI known issue
in CLAUDE.md); two commands on a desktop.

### Option B: One playbook with tags / `when:` on the OS and session

| Dimension | Assessment |
|-----------|------------|
| Complexity | Med: every GUI task needs a guard |
| Portability | Same, if every guard is right |
| Maintenance | Med: a missing guard breaks headless/non-Fedora runs |
| Familiarity | Plain Ansible |

**Pros:** one command; shared steps written once.
**Cons:** the common case (a terminal on a random box) pays for the rare one; mistakes in
guards surface on the machines that matter most to be predictable.

### Option C: Roles + `site.yml` (cli role, gui role)

| Dimension | Assessment |
|-----------|------------|
| Complexity | High for the size of the repo |
| Portability | Same as A |
| Maintenance | Med: role scaffolding, defaults, meta |
| Familiarity | Ansible best practice |

**Pros:** shared tasks can become a third role; scales to many hosts.
**Cons:** much more structure than two short playbooks need.

### Option D: A dotfiles manager (chezmoi, yadm, bare git repo) instead of Ansible

| Dimension | Assessment |
|-----------|------------|
| Complexity | Low for files, but packages/installers need scripts |
| Portability | Good |
| Maintenance | Med: package installs move to shell scripts |
| Familiarity | New tool to learn |

**Pros:** purpose-built for files and templating.
**Cons:** the repo also installs packages, flatpaks, starship, Zi and changes the login shell;
Ansible already does that idempotently and supports remote hosts and `ansible-pull`.

## Trade-off Analysis

The main goal is a predictable terminal everywhere; the desktop is a single-distro extra.
Splitting by that line (A) keeps the common path minimal and makes the GUI's platform
assumptions harmless. B saves one command but spreads GUI guards through the CLI path.
C is the "proper" version of A and becomes worth it only if shared logic grows.
D would replace a working installer with scripts.

## Consequences

- Easier: bootstrap of servers/VMs; changing the GUI without risking the CLI.
- Harder: keeping shared steps (clone, link method) consistent between the two playbooks.
- Revisit: if shared tasks grow, extract a role (Option C). Rename `cli.yaml` →
  `cli.yaml` for symmetry (postponed: breaks existing `ansible-pull` commands).

## Action Items

1. [x] Split KDE out of the CLI playbook (`konsave.yaml`, later `gui.yaml`).
2. [x] Align `gui.yaml` with ADR-0002 (stow, `main`, no forced updates): see ADR-0004.
3. [ ] Rename `cli.yaml` → `cli.yaml` and update README.
