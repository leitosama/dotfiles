# ADR-0005: Dependabot with auto-merge for minor bumps, Claude action for the rest

**Status:** Proposed; the Claude action part superseded by ADR-0008
**Date:** 2026-10-01
**Deciders:** leitosama

## Context

The repo has few dependencies: GitHub Actions in `lint.yml`, `ansible` and `ansible-lint` in
`requirements.txt`, the devcontainer image. Nothing watches them, and drift shows up only as a
broken lint run, such as the `INJECT_FACTS_AS_VARS` deprecation. The same setup already works in
`leitosama/freshrss-mcp-server`.

## Decision

Reuse that setup: Dependabot weekly for `github-actions`, `pip` and `devcontainers`;
`dependabot-auto-merge.yml` enables auto-merge for patch/minor; majors and red PRs are handled by
commenting `@claude` (`claude.yml`, `anthropics/claude-code-action`). Lint runs with
`strict: true` and `ANSIBLE_INJECT_FACTS_AS_VARS=false`, so ansible-core deprecations fail CI
in the PR that bumps ansible, not on a machine.

## Options Considered

### Option A: Keep updating by hand

| Dimension | Assessment |
|-----------|------------|
| Complexity | Low |
| Maintenance | Easy to forget, found when something breaks |

### Option B: Dependabot only, merge by hand

Safe, but every minor bump costs a manual merge.

### Option C: Dependabot + auto-merge + Claude action (chosen)

**Pros:** minor bumps need no attention; hard ones get a fix PR on request.
**Cons:** needs repo settings and the `ANTHROPIC_API_KEY` secret; auto-merge is only as safe as
the lint check, which is the whole test suite here.

## Trade-off Analysis

`konsave` (pipx), `stow` and other distro packages are installed unpinned, so they are always
latest and Dependabot has nothing to bump. Pinning them to get PRs would add a version to
maintain per machine for no gain. The starship and Zi installers are fetched from upstream
likewise.

## Consequences

- Minor bumps merge on their own after Lint passes.
- A break from an unpinned tool (konsave, stow) is not caught by CI; the Fedora VM check from ADR-0004 stays manual.

## Action Items

1. [ ] Enable "Allow auto-merge", require the Lint check on `main`, add `ANTHROPIC_API_KEY`.
2. [ ] Install the Claude GitHub app if it is not installed.
