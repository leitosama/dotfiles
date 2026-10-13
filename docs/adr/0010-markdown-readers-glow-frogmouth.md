# ADR-0010: Markdown in the terminal: glow everywhere, frogmouth on the desktop

**Status:** Proposed
**Date:** 2026-10-13
**Deciders:** leitosama

## Context

READMEs and notes are read in the terminal on the laptop and over SSH on servers. `less`
shows raw markup. The reader has to work on any host `cli.yaml` targets, without a runtime
(Python, Node) on servers, and be installable from the distro so the playbook stays simple.
On the desktop it is also useful to follow links between files of a documentation tree.

## Decision

- **glow** in `cli.yaml`, from the distro package (Arch, Fedora, Debian 13+, Homebrew).
  Where it is not packaged (older Debian/Ubuntu) the task reports `SKIP` instead of failing.
- **frogmouth** in `gui.yaml`, a user install with pipx: it is not packaged by the distros
  nor on Flathub.
- One entry point, the `md` function in `zshrc`: frogmouth where it is installed (the
  desktop), glow otherwise, `less` (raw text) where neither is. Piped input and directories
  always go to glow, frogmouth only opens files. No `bat` fallback: nothing installs it.
- Konsole's `leito` profile allows OSC 8 links (`AllowEscapedLinks`). glow 3.0+ emits them,
  so the link text opens on click; glow 2.x (Fedora 43/44) prints the URL next to the text,
  which Konsole detects as a plain URL.

## Options Considered

### Option A: glow (+ frogmouth on the desktop)

| Dimension | Assessment |
|-----------|------------|
| Complexity | Low: one package; pipx for frogmouth |
| Portability | glow: Linux, macOS, one static Go binary; frogmouth: anywhere with Python |
| Maintenance | glow active (Charm); frogmouth's last release is 0.9.2 (2023, pins textual 0.43) |
| Familiarity | glow is the best known terminal markdown renderer |

**Pros:** glow renders well, has a file browser, a pager, stdin input and, from 3.0,
clickable OSC 8 links; frogmouth adds what glow lacks: following links between files, history, bookmarks.
**Cons:** frogmouth is unmaintained, kept isolated in its own pipx venv; if it breaks,
uninstalling it makes `md` fall back to glow.

### Option B: leaf (RivoLink/leaf)

| Dimension | Assessment |
|-----------|------------|
| Complexity | Low |
| Portability | Homebrew, AUR, npm, curl script; not in Fedora or Debian |
| Maintenance | Young, active |
| Familiarity | Low |

**Pros:** live preview with watch mode, TOC, Mermaid and LaTeX: a good companion while writing.
**Cons:** not in the distro repos `cli.yaml` relies on; a writing tool more than a reader.

### Option C: lowdown / bat only

**Pros:** in every distro, tiny. **Cons:** lowdown has no pager or browser; bat only
highlights the markup, it doesn't render it.

### Option D: keep `less`

**Pros:** nothing to install. **Cons:** raw markup.

## Trade-off Analysis

glow covers both the laptop and servers with one tool and no runtime, so it goes to the CLI
playbook. Its only gap, navigation between files, matters on the desktop, where a Python
app in a pipx venv costs nothing. leaf is attractive for writing but not packaged where
servers need it; it can be added to the desktop later without changing `md`.

## Consequences

- `md file.md`, `md` and `… | md` work on every host: frogmouth on the desktop, glow on
  servers, `less` where glow is not packaged.
- pipx becomes a GUI dependency, the place for other PyPI-only terminal apps.
- frogmouth may break on a future Python; then drop it from `pipx_apps` and `md` uses glow.

## Action Items

1. [x] glow in `cli.yaml`, frogmouth via pipx in `gui.yaml`, `md` in `zshrc`
2. [x] OSC 8 links in the Konsole profile
3. [ ] Revisit frogmouth if it stops working on the distro Python
