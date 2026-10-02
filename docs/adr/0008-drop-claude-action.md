# ADR-0008: Drop the Claude GitHub Action

**Status:** Proposed
**Date:** 2026-10-02
**Deciders:** leitosama

## Context

ADR-0005 added `claude.yml` (`anthropics/claude-code-action`) so that commenting `@claude` on a
major or red Dependabot PR would produce a fix. It needs an `ANTHROPIC_API_KEY` (or
`CLAUDE_CODE_OAUTH_TOKEN`) Actions secret, which was never added. All of its runs were
triggered by comments without the trigger phrase and exited early, so it has never worked.
The repo is also about to be recreated, which drops every repo secret and setting.

## Decision

Remove `claude.yml`. Dependabot and `dependabot-auto-merge.yml` stay as in ADR-0005: patch and
minor bumps merge once Lint is green. A major or red Dependabot PR is fixed by hand or in a
Claude Code session opened on the repo, which needs no secret in the repo.

## Options Considered

### Option A: Remove the workflow (chosen)

**Pros:** nothing to configure when the repo is recreated; no secret to keep; one workflow less
for Dependabot to bump.
**Cons:** `@claude` in a PR comment does nothing; a fix needs a session started by hand.

### Option B: Keep it with a subscription token

`claude setup-token` (Pro/Max) and a `CLAUDE_CODE_OAUTH_TOKEN` secret, or `/install-github-app`.
**Pros:** fixes on request from a PR comment.
**Cons:** a secret to create and rotate per repo; for a few Dependabot majors a year.

## Trade-off Analysis

The action saves starting a session for the rare PR that Dependabot can't merge on its own;
that does not pay for a secret that has to be recreated with the repo.

## Consequences

- Repo settings needed: "Allow auto-merge" and Lint as a required check on `main`; no secrets.
- Revisit if majors or red Dependabot PRs become frequent (Option B).

## Action Items

1. [x] Remove `.github/workflows/claude.yml`, update CLAUDE.md and the auto-merge comment.
