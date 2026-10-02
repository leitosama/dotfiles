# ADR-0007: KDE as a Global Theme package and settings keys, no konsave snapshot

**Status:** Proposed
**Date:** 2026-10-02
**Deciders:** leitosama

## Context

ADR-0004 kept KDE settings as a konsave snapshot of whole rc files. In practice:

- The snapshot was never saved again after it was taken, so it held defaults plus a few
  real preferences (Night Color, KRunner on Meta, tiling gap, panels).
- Whole rc files carry machine data next to settings: GTK bookmarks and recent servers, the
  file dialog history, wallpaper and launcher paths, file names on the desktop
  (`[ScreenMapping]` in `appletsrc`). All of it ended up in a public repo and had to be
  removed from the history.
- `konsave -a` overwrites whole files, so a fix could not be rolled out to a running desktop
  without `-e kde_apply=true` resetting everything else.
- Panels (`appletsrc`) referenced widgets and launchers missing on other machines, which
  showed up as empty slots.
- The desktop is getting a theme (One Dark Pro Night Flat on Breeze, Papirus-Dark icons) that
  must reach every machine and be easy to adjust later.

Facts that shape the decision (Plasma 6 sources):

- At login `startplasma` compares the SHA-1 of the file named by `kdeglobals [General]
  ColorScheme` with `ColorSchemeHash` and re-applies the colors when they differ. Setting the
  key is enough; editing the `.colors` file is picked up at the next login.
- When `kdeglobals [KDE] LookAndFeelPackage` changes, its `contents/defaults` are written to
  `~/.config/kdedefaults` (a defaults layer under the user's config).
- When plasmashell starts without a layout, it runs the Global Theme's
  `contents/layouts/org.kde.plasma.desktop-layout.js`. The scripting API is JavaScript only and
  has `knownWidgetTypes` and `applicationExists()`, so the script can skip what is missing.
- KPackage refuses files whose real path is outside the package directory, so a Global Theme
  cannot be linked file by file (stow `--no-folding`); its directory has to be one link.

## Decision

- **Theme files** that KDE only writes on explicit edits (the color scheme, the Konsole color
  scheme and profile) are in the `kde` stow package.
- **Global Theme `leito`** in `lookandfeel/leito/`: theme defaults (Breeze widgets and window
  decoration, the color scheme, Papirus-Dark, Breeze Plasma style) and the panel layout script.
  `~/.local/share/plasma/look-and-feel/leito` is a link to that directory.
- **Panels are saved and loaded with Plasma's own serializer.** `kde-panels-save` takes
  `dumpCurrentLayoutJS` from plasmashell over D-Bus (what plasma-sdk's Look and Feel Explorer
  uses), drops desktops and machine-local keys, and writes the JSON into the layout script;
  `--push` commits and pushes it. The script filters out widgets and apps missing on the
  machine, then calls `loadSerializedLayout`. `kde-panels-load` replaces the live panels with
  it through `evaluateScript`, leaving theme, desktops and wallpapers alone.
- **Settings are keys**: `kde_settings` in `gui.yaml` lists file/group/key/value; each run reads
  them with `kreadconfig6` and writes with `kwriteconfig6` only the ones that differ. The theme
  keys repeat `contents/defaults`, so machines that already set them explicitly converge too.
- GTK apps use Breeze GTK (`gtk-theme-name`), which follows Plasma's colors through
  kde-gtk-config; flatpak apps get read access to `~/.config/gtk-{3,4}.0`.
- konsave, `konsave/`, the marker and `kde_apply` are removed; `gui.yaml` cleans up the old
  link, the marker and the pipx install. Machine data (file associations, mouse, wallpaper,
  timezone) is not versioned.

## Options Considered

### Option A: Global Theme + settings keys (chosen)

| Dimension | Assessment |
|-----------|------------|
| Complexity | Med: a key list, one package directory, a layout script |
| Portability | Plasma 6 on Arch and Fedora |
| Maintenance | Low: plain KDE tools (`kwriteconfig6`, KPackage), no third-party tool |
| Familiarity | KDE's own formats (`.colors`, look-and-feel packages, scripting API) |

**Pros:** idempotent, merges with local settings, rolls out with a plain rerun; only chosen
values are in git; panels adapt to what is installed; the theme is also one click in System
Settings.
**Cons:** a setting is found and added by hand; panels are saved by running `kde-panels-save`,
not automatically.

### Option B: keep the konsave snapshot (ADR-0004)

| Dimension | Assessment |
|-----------|------------|
| Complexity | Low |
| Portability | Plasma 5 and 6 |
| Maintenance | Med: every save must be reviewed for machine data |
| Familiarity | Known here |

**Pros:** saving is one command.
**Cons:** see Context: leaks machine data, overwrites whole files, panels break across machines.

### Option C: konsave only for panels, keys for the rest

| Dimension | Assessment |
|-----------|------------|
| Complexity | Med: two mechanisms |
| Portability | Same as A |
| Maintenance | Med |
| Familiarity | Known |

**Pros:** panels saved with the mouse.
**Cons:** `appletsrc` is the file that leaked desktop file names and broke on other machines.

### Option D: separate color scheme, Kvantum or Aurorae themes from other projects

**Cons:** Kvantum needs a flatpak extension per runtime version (most KDE apps here are
flatpaks, ADR-0006); Aurorae decorations scale poorly; no maintained One Dark Pro port exists
for Plasma 6. Breeze reads every color from the scheme, so one `.colors` file is enough.

## Trade-off Analysis

The snapshot model optimised for "save with one command", which turned out not to be used,
and paid for it with leaked data and destructive applies. Keys make the three moments from
CLAUDE.md work for KDE as they do for the CLI: bootstrap and roll out are the same rerun, and
saving is adding a line. Panels are the one thing keys can't express; Plasma's serialized
layout covers them, and filtering it on load makes it portable, unlike a saved `appletsrc`.

## Consequences

- Easier: rolling out theme or settings changes (`gui.yaml` rerun, log in again); reviewing
  what is versioned; new machines get the panels without empty slots.
- Harder: capturing a setting changed in the GUI (find the key, add it).
- Revisit: flatpak theme extensions (Papirus, Breeze GTK) if flatpak apps don't pick the icons
  or GTK colors up; widgets from the KDE Store (Fokus) are not installed by the playbook.

## Action Items

1. [x] Color scheme and Konsole scheme (`stow/kde`), Global Theme `leito`, `kde_settings`,
   `kde-panels-save` / `kde-panels-load`.
2. [x] Remove konsave and its CI check; clean up the link, marker and pipx install.
3. [ ] After merge: remove `config/konsave/profiles`, `gui_config` and `konsave/profiles` from
   the git history (they hold machine data).
4. [ ] Check on the desktop: rerun is unchanged, colors after login, flatpak apps;
   `kde-panels-save` once to replace the default panels in the script, then `kde-panels-load`.
