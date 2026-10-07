# Architecture Decision Records

Why the repo looks the way it does. One file per decision, numbered, never rewritten:
when a decision changes, add a new ADR and mark the old one `Superseded by ADR-NNNN`.

| ADR | Title | Status |
|-----|-------|--------|
| [0001](0001-two-ansible-playbooks-cli-and-gui.md) | Two Ansible playbooks: CLI and GUI | Accepted |
| [0002](0002-gnu-stow-single-clone.md) | Link configs with GNU Stow from a single clone on `main` | Accepted |
| [0003](0003-zi-zsh-plugin-manager.md) | Zi as the zsh plugin manager (replaces antigen) | Accepted |
| [0004](0004-kde-konsave-snapshot.md) | KDE configs as a konsave snapshot, stable files through stow | Superseded by 0007 |
| [0005](0005-dependabot-and-claude-action.md) | Dependabot with auto-merge for minor bumps, Claude action for the rest | Proposed; Claude action superseded by 0008 |
| [0006](0006-gui-distro-agnostic-flatpak-apps.md) | GUI playbook on any distro (Arch, Fedora), end-user apps from Flathub | Proposed |
| [0007](0007-kde-global-theme-and-settings-keys.md) | KDE as a Global Theme package and settings keys, no konsave snapshot | Proposed |
| [0008](0008-drop-claude-action.md) | Drop the Claude GitHub Action | Proposed |
| [0009](0009-npm-prefix-via-environment.md) | npm global prefix via environment, not a stow package | Proposed |

## Writing a new ADR

The format follows the `engineering:architecture` skill
([anthropics/knowledge-work-plugins](https://github.com/anthropics/knowledge-work-plugins/blob/main/engineering/skills/architecture/SKILL.md)).
With the Engineering plugin enabled, run `/architecture <decision>`; otherwise copy
[template.md](template.md).

1. Next free number, kebab-case title: `NNNN-short-title.md`.
2. Status `Proposed` while it is discussed in a PR, `Accepted` when merged.
3. Name at least two real options, including "keep what we have".
4. Add a row to the table above.
