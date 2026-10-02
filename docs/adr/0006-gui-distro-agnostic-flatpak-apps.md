# ADR-0006: GUI playbook on any distro (Arch, Fedora), end-user apps from Flathub

**Status:** Proposed
**Date:** 2026-10-01
**Deciders:** leitosama

## Context

ADR-0001 made `gui.yaml` Fedora-only. The desktops are Arch Linux and Fedora, so that was
too narrow: the playbook used `dnf` for everything and could not run on Arch at all.

The split between distro packages and flatpak comes from Arch: it is rolling and does not
support partial upgrades. Holding Okular at an older version was impossible, and upgrading it
pulled the whole Qt/KDE Frameworks stack with it. A Flathub app ships against its own runtime
(`org.kde.Platform`), so its version is independent from the system libraries and can be
pinned or rolled back alone (`flatpak mask`, `flatpak update --commit`).

The sandbox is not free, though. Checking the Flathub manifests of the apps installed so far:

| App | Flathub permissions | Verdict |
|-----|---------------------|---------|
| okular | `host` filesystem | flatpak: the original reason |
| gwenview | `host`, thumbnails, trash | flatpak |
| kcalc | none needed | flatpak |
| krdc | network only | flatpak: FreeRDP bundled, independent from the system one |
| kamoso | pipewire, all devices | flatpak |
| filelight | no filesystem at all | distro: can't scan the disk, which is its only job |
| kleopatra | `~/.gnupg:create`, host agent socket | distro: bundles its own gnupg on the host keyring, next to the host gpg-agent (git signing, smartcards) |
| kwalletmanager | `org.kde.kwalletmanager5` stopped at runtime 6.8, the live id is `org.kde.kwalletmanager` | distro: a D-Bus client of kwalletd, which comes with Plasma anyway |

Plasma itself, konsole, dolphin and ark stay distro packages too: they are the session,
and konsole in a sandbox can't run host shells without `flatpak-spawn`.

State of KDE on Flathub (2026-10-01, 177 `org.kde.*` apps checked against Arch and Fedora 44):

- KDE Gear builds land unevenly: kcalc, elisa and the games are on 26.08.1 like Arch, while
  okular, gwenview, krdc, kate, ark and dolphin are still on 26.04.x, one Gear release
  (2–3 months) behind, security fixes included. That lag is accepted: stability and rollback
  matter more here than freshness. Fedora 44 itself ships Gear 25.12, older than both.
- Some apps are still on the Qt5 runtime (5.15): okteta, krename, kaffeine, kbibtex.
- Not on Flathub at all: spectacle, kdeconnect, partitionmanager, ksystemlog, kmail.

More apps, chosen by the same rule:

| App | Verdict |
|-----|---------|
| kolourpaint, haruna, elisa, ktorrent, kdiff3, okteta, kcharselect, kcolorchooser | flatpak: standalone |
| kate | flatpak, used as a notepad; as an IDE it needs host LSP servers, git and a terminal → distro |
| akregator | flatpak: standalone feeds, at the cost of Kontact's Akregator tab |
| kontact, kmail, korganizer, kaddressbook, merkuro | distro: Akonadi is a session service, mail crypto uses the host gpg-agent |
| spectacle, kdeconnect, ksystemlog | distro: KWin's restricted screenshot API, a session daemon, the host journal; none on Flathub |

## Decision

- `gui.yaml` runs on any Linux with a `kde_desktop` entry for its `os_family`: `RedHat`
  (Fedora's `@kde-desktop-environment` group via `dnf`) and `Archlinux` (`plasma-meta`,
  konsole, dolphin, ark). Everything else uses `ansible.builtin.package`; app lists use Arch
  names, and `kde_package_renames` maps the few that differ (`kdeconnect` → `kde-connect`,
  `elisa` → `elisa-player` on Fedora).
  An unknown distro fails before installing anything.
- Rule for apps: **standalone end-user apps come from Flathub** (user install), so their
  version doesn't follow the distro's Qt/KF upgrades. **Apps that integrate with the
  session or the host** (D-Bus services, gpg-agent, raw filesystem access, terminals) come
  from the distro.
- Flathub is added as a user remote by the playbook: a user installation does not see the
  system remotes.
- The distro version of a flatpak app is removed (and excluded from Fedora's group), so there
  is one copy of each app and one `.desktop` entry.

## Options Considered

### Option A: per-family package lists, flatpak only where the sandbox doesn't hurt (chosen)

| Dimension | Assessment |
|-----------|------------|
| Complexity | Low: two small maps keyed by `os_family` |
| Portability | Arch and Fedora; another distro is one line in `kde_desktop` |
| Maintenance | Low: app names are identical on Arch and Fedora |
| Familiarity | Plain Ansible |

**Pros:** fixes the Arch problem for the apps where it matters; integration-heavy apps keep
working.
**Cons:** two kinds of apps to update (`pacman`/`dnf` and `flatpak update`); each KDE
runtime version on Flathub is a few hundred MB.

### Option B: everything from Flathub

| Dimension | Assessment |
|-----------|------------|
| Complexity | Low |
| Portability | Any distro |
| Maintenance | Med: workarounds for sandbox breakage (Flatseal overrides) |
| Familiarity | Same |

**Pros:** one rule, every app pinnable.
**Cons:** filelight can't see the disk, kleopatra runs a second gnupg on the same keyring,
kwalletmanager's Flathub id was already abandoned once.

### Option C: everything from the distro (keep what Fedora had before flatpak)

| Dimension | Assessment |
|-----------|------------|
| Complexity | Lowest |
| Portability | Any distro |
| Maintenance | Low |
| Familiarity | Same |

**Pros:** no sandbox, no runtimes.
**Cons:** on Arch an app can't be held back or rolled back without holding the whole
desktop: the problem this split exists for.

### Option D: separate playbooks per distro (`gui-arch.yaml`, `gui-fedora.yaml`)

**Pros:** no `when:` on the family.
**Cons:** konsave, stow and flatpak steps duplicated; they would drift like the clone did
before ADR-0004.

## Trade-off Analysis

The pain is version coupling on a rolling distro, and it only matters for apps you actually
care about the version of (Okular). Flatpak solves exactly that and costs nothing for
self-contained apps; for apps whose job is to talk to the host it trades a theoretical
version problem for a real breakage. So the line is drawn per app, by what the sandbox does
to it, and written next to each app in `gui.yaml`.

## Consequences

- Easier: running the desktop setup on Arch; pinning or rolling back a single app.
- Harder: a new app needs a decision (see the rule above), a new distro needs a
  `kde_desktop` entry.
- Revisit: kamoso is barely maintained upstream; if Flathub drops it, drop it here.
  The display manager is not enabled by the playbook (Fedora's group does it, Arch's
  `plasma-meta` brings `plasma-login-manager` but leaves enabling it to you).

## Action Items

1. [x] Per-family package lists in `gui.yaml`, Flathub as a user remote.
2. [x] Move filelight, kleopatra and kwalletmanager to distro packages; remove their flatpaks.
3. [x] Add the apps from the table above (graphics, media, utilities, PIM, system tools).
4. [ ] Run on the Arch desktop and on Fedora, then mark this ADR Accepted.
